const crypto = require("crypto");

const { onRequest } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const play = require("./play");
const { sendEmail, escapeHtml } = require("./alerts");
const adminModule = require("./admin");

exports.adminApi = adminModule.adminApi;
exports.adminDailyDigest = adminModule.adminDailyDigest;

const asaasKeyParam = defineString("ASAAS_API_KEY");
const webhookTokenParam = defineString("ASAAS_WEBHOOK_TOKEN");
const asaasBaseParam = defineString("ASAAS_BASE_URL", {
  default: "https://api.asaas.com/v3",
});

function env(name, fallback = "") {
  let raw = "";
  try {
    if (name === "ASAAS_API_KEY") raw = asaasKeyParam.value();
    else if (name === "ASAAS_WEBHOOK_TOKEN") raw = webhookTokenParam.value();
    else if (name === "ASAAS_BASE_URL") raw = asaasBaseParam.value();
  } catch (_) {
    raw = process.env[name] || fallback;
  }
  const value = String(raw || fallback).trim();
  if (!value || value === "UNSET") return "";
  return value;
}

const REGION = "southamerica-east1";
const PREMIUM_VALUE = 39.9;

const PAID_EVENTS = new Set([
  "PAYMENT_CONFIRMED",
  "PAYMENT_RECEIVED",
  "PAYMENT_RECEIVED_IN_CASH",
]);

const PAID_STATUS = new Set(["CONFIRMED", "RECEIVED", "RECEIVED_IN_CASH"]);

const httpOptions = {
  region: REGION,
  cors: true,
  invoker: "public",
};

exports.asaasWebhook = onRequest(httpOptions, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Use POST");
    return;
  }

  const expected = env("ASAAS_WEBHOOK_TOKEN");
  const received = req.get("asaas-access-token") || "";
  if (!expected) {
    res.status(503).json({ ok: false, message: "Webhook ainda sem token." });
    return;
  }
  if (!tokensMatch(received, expected)) {
    res.status(401).json({ ok: false, message: "Token inválido." });
    return;
  }

  const event = req.body?.event;
  const payment = req.body?.payment;
  if (!isPaid(event, payment)) {
    res.status(200).json({ ok: true, ignored: true });
    return;
  }

  const userId = String(payment.externalReference || "").trim();
  if (!userId) {
    res.status(200).json({ ok: false, message: "Cobrança sem externalReference." });
    return;
  }

  if (payment.id) {
    await saveCharge(payment.id, userId, payment.status || "RECEIVED");
  }
  await grantPremium(userId, payment.id || null);
  res.status(200).json({ ok: true, userId });
});

exports.createPremiumPix = onRequest(httpOptions, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ message: "Use POST" });
    return;
  }

  try {
    const user = await requireUser(req);
    const key = env("ASAAS_API_KEY");
    if (!key) {
      res.status(503).json({ message: "O PIX do Asaas ainda não está ligado." });
      return;
    }

    const name = String(req.body?.name || "").trim();
    const email = String(req.body?.email || "").trim();
    const cpf = String(req.body?.cpf || "").replace(/\D/g, "");
    if (!name || !email.includes("@")) {
      res.status(400).json({ message: "Informe nome, e-mail e a conta." });
      return;
    }

    const customerId = await customerIdFor({
      apiKey: key,
      userId: user.uid,
      name,
      email,
      cpf,
    });
    const due = new Date();
    const dueDate = due.toISOString().slice(0, 10);
    const payment = await asaas("POST", "/payments", key, {
      customer: customerId,
      billingType: "PIX",
      value: PREMIUM_VALUE,
      dueDate,
      description: "Pagô Premium",
      externalReference: user.uid,
    });
    const paymentId = payment.id || "";
    const qr = await asaas("GET", `/payments/${paymentId}/pixQrCode`, key, null);
    await saveCharge(paymentId, user.uid, payment.status || "PENDING");
    res.status(200).json({
      paymentId,
      payload: qr.payload || "",
      encodedImage: qr.encodedImage || "",
      status: payment.status || "PENDING",
    });
  } catch (error) {
    const status = error.status || 502;
    res.status(status).json({ message: error.message || "Falha ao gerar o PIX." });
  }
});

exports.premiumPixStatus = onRequest(httpOptions, async (req, res) => {
  if (req.method !== "GET") {
    res.status(405).json({ message: "Use GET" });
    return;
  }

  try {
    const user = await requireUser(req);
    const paymentId = lastSegment(req.path);
    if (!paymentId) {
      res.status(400).json({ message: "Informe a cobrança." });
      return;
    }

    const charge = await admin.firestore().collection("PremiumCharges").doc(paymentId).get();
    if (!charge.exists || charge.data().userId !== user.uid) {
      res.status(404).json({ message: "Cobrança não encontrada." });
      return;
    }

    let status = charge.data().status || "PENDING";
    if (!PAID_STATUS.has(String(status).toUpperCase())) {
      const key = env("ASAAS_API_KEY");
      if (key) {
        const remote = await asaas("GET", `/payments/${paymentId}`, key, null);
        status = remote.status || status;
        await saveCharge(paymentId, user.uid, status);
      }
    }

    if (PAID_STATUS.has(String(status).toUpperCase())) {
      await grantPremium(user.uid, paymentId);
    }

    res.status(200).json({ status });
  } catch (error) {
    const code = error.status || 502;
    res.status(code).json({ message: error.message || "Não foi possível consultar o PIX." });
  }
});

exports.confirmPlayPurchase = onRequest(httpOptions, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ message: "Use POST" });
    return;
  }

  try {
    const user = await requireUser(req);
    const transactionId = String(req.body?.transactionId || "").trim().slice(0, 120);
    const purchaseToken = String(req.body?.purchaseToken || "").trim();
    if (!purchaseToken) {
      res.status(400).json({ message: "Atualize o app para confirmar a assinatura." });
      return;
    }

    let summary;
    try {
      summary = await play.fetchSubscription(purchaseToken);
    } catch (error) {
      console.warn("API da Play indisponível; liberando 30 dias sem conferir.", error.message);
      await play.linkUnverified(user.uid, purchaseToken, transactionId);
      await grantPremium(user.uid, transactionId || `play_${Date.now()}`);
      const fallback = { orderId: transactionId, price: PREMIUM_VALUE, test: false };
      if (await play.logPlayEvent(user.uid, "COMPRA", fallback)) await alertNewSubscriber(user, fallback);
      res.status(200).json({ ok: true, verificada: false });
      return;
    }

    if (summary.uid && summary.uid !== user.uid) {
      res.status(403).json({ message: "Esta assinatura pertence a outra conta do Pagô." });
      return;
    }
    if (!play.isActive(summary)) {
      res.status(402).json({ message: "A Google Play não mostra esta assinatura como ativa." });
      return;
    }
    await play.applySubscription(user.uid, purchaseToken, summary);
    const known = summary.orderId
      ? await admin.firestore().collection("PlayEvents").where("orderId", "==", summary.orderId).limit(1).get()
      : { empty: true };
    if (known.empty && (await play.logPlayEvent(user.uid, "COMPRA", summary))) {
      await alertNewSubscriber(user, summary);
    }
    res.status(200).json({ ok: true, verificada: true });
  } catch (error) {
    res.status(error.status || 401).json({
      message: error.message || "Não foi possível confirmar a compra.",
    });
  }
});

const ALERT_TYPES = {
  CANCELADA: "cancelou a renovação",
  SUSPENSA: "teve o pagamento recusado (assinatura suspensa)",
  PERIODO_DE_CARENCIA: "teve o pagamento recusado (em carência)",
  ESTORNADA: "teve a compra estornada",
  EXPIRADA: "perdeu o Premium (assinatura expirou)",
};

exports.playNotifications = onMessagePublished(
  { topic: "play-billing", region: REGION },
  async (event) => {
    const data = event.data?.message?.json || {};
    if (data.testNotification) {
      console.log("Aviso de teste da Play recebido.");
      return;
    }
    const notification = data.subscriptionNotification;
    if (!notification?.purchaseToken) return;
    const type =
      play.NOTIFICATION_TYPES[notification.notificationType] || `TIPO_${notification.notificationType}`;

    let summary;
    try {
      summary = await play.fetchSubscription(notification.purchaseToken);
    } catch (error) {
      console.error("Não foi possível consultar a assinatura na Play.", type, error.message);
      return;
    }
    const uid = await play.uidForToken(notification.purchaseToken, summary);
    if (uid) await play.applySubscription(uid, notification.purchaseToken, summary);
    const created = await play.logPlayEvent(uid, type, summary);
    if (!created) return;

    const person = uid ? await describeUser(uid) : null;
    if (type === "COMPRA" && person) {
      await alertNewSubscriber(person, summary);
    } else if (ALERT_TYPES[type]) {
      await sendEmail(`Pagô: ${person?.nome || "assinante"} ${ALERT_TYPES[type]}`, [
        `<b>${escapeHtml(person?.nome || "Assinante sem conta ligada")}</b> ${ALERT_TYPES[type]}.`,
        person?.email ? `E-mail: ${escapeHtml(person.email)}` : "",
        summary.expiry ? `Premium vale até ${new Date(summary.expiry).toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" })}.` : "",
        summary.test ? "Compra de teste (conta de teste de licença)." : "",
      ].filter(Boolean));
    }
  },
);

async function describeUser(uid) {
  const [record, profile] = await Promise.all([
    admin.auth().getUser(uid).catch(() => null),
    admin.firestore().collection("Users").doc(uid).get(),
  ]);
  return {
    uid,
    nome: profile.data()?.nome || record?.displayName || "",
    email: record?.email || profile.data()?.email || "",
  };
}

async function alertNewSubscriber(user, summary) {
  const person = user.nome !== undefined ? user : await describeUser(user.uid);
  await sendEmail(`Pagô: nova assinatura de ${person.nome || person.email || "alguém"}`, [
    `<b>${escapeHtml(person.nome || "Sem nome")}</b> assinou o Premium.`,
    person.email ? `E-mail: ${escapeHtml(person.email)}` : "",
    `Valor: R$ ${Number(summary.price || PREMIUM_VALUE).toFixed(2).replace(".", ",")} por mês.`,
    summary.test ? "Compra de teste (conta de teste de licença)." : "",
  ].filter(Boolean));
}

async function requireUser(req) {
  const header = req.get("authorization") || "";
  const match = /^Bearer (.+)$/i.exec(header);
  if (!match) {
    const error = new Error("Entre na conta para continuar.");
    error.status = 401;
    throw error;
  }
  try {
    return await admin.auth().verifyIdToken(match[1]);
  } catch (_) {
    const error = new Error("Sessão expirada. Entre de novo.");
    error.status = 401;
    throw error;
  }
}

async function grantPremium(userId, transactionId) {
  const expires = new Date();
  expires.setDate(expires.getDate() + 30);
  await admin.firestore().collection("Users").doc(userId).set(
    {
      is_premium: true,
      premium_vence_em: admin.firestore.Timestamp.fromDate(expires),
      premium_transaction_id: transactionId || null,
    },
    { merge: true },
  );
}

async function saveCharge(paymentId, userId, status) {
  if (!paymentId) return;
  await admin.firestore().collection("PremiumCharges").doc(paymentId).set(
    {
      userId,
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function customerIdFor({ apiKey, userId, name, email, cpf }) {
  const found = await asaas(
    "GET",
    `/customers?externalReference=${encodeURIComponent(userId)}`,
    apiKey,
    null,
  );
  const first = Array.isArray(found.data) ? found.data[0] : null;
  if (first?.id) return first.id;
  const created = await asaas("POST", "/customers", apiKey, {
    name,
    email,
    externalReference: userId,
    ...(cpf.length === 11 || cpf.length === 14 ? { cpfCnpj: cpf } : {}),
  });
  if (!created.id) {
    throw new Error("O Asaas não devolveu o cliente.");
  }
  return created.id;
}

async function asaas(method, path, apiKey, body) {
  const base = env("ASAAS_BASE_URL", "https://api.asaas.com/v3").replace(/\/+$/, "");
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      access_token: apiKey,
      "content-type": "application/json",
      "user-agent": "Pago/2.4.0",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const decoded = text ? JSON.parse(text) : {};
  if (response.status >= 400) {
    throw new Error(asaasMessage(decoded));
  }
  return decoded;
}

function asaasMessage(body) {
  const errors = body?.errors;
  if (Array.isArray(errors) && errors[0]?.description) {
    return errors[0].description;
  }
  return "O Asaas recusou a cobrança.";
}

function isPaid(event, payment) {
  if (!payment || typeof payment !== "object") return false;
  return PAID_EVENTS.has(event) || PAID_STATUS.has(payment.status);
}

function tokensMatch(received, expected) {
  if (!received || !expected) return false;
  const left = Buffer.from(received);
  const right = Buffer.from(expected);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function lastSegment(path) {
  const parts = String(path || "")
    .split("/")
    .filter(Boolean);
  return parts[parts.length - 1] || "";
}
