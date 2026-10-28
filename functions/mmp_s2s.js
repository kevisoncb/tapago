const admin = require("firebase-admin");
const crypto = require("crypto");

/**
 * Receita para o MMP (AppsFlyer) servidor a servidor.
 *
 * Variáveis em functions/.env (sem elas nada é enviado):
 *   MMP_S2S_URL         ex.: https://api2.appsflyer.com/inappevent/{app_id}
 *   MMP_S2S_TOKEN       AppsFlyer → Configurações → API tokens → S2S token
 *   MMP_APP_ID_ANDROID  padrão app.usepago
 *   MMP_APP_ID_IOS      "id" + Apple ID numérico (ex.: id6740000000)
 *   MMP_STORE_FEE       taxa da loja, padrão 0.15 (Small Business Program / assinaturas da Play)
 *
 * O aparelho entra por MmpIds/{uid} (só servidor), gravado quando o app
 * confirma a compra mandando o id da AppsFlyer. Quem chama garante que cada
 * cobrança é enviada uma vez (PlayEvents com create()).
 */
const EVENT_NAMES = {
  COMPRA: "af_subscribe",
  RENOVADA: "af_renewal",
  RECUPERADA: "af_renewal",
};

const PLATFORMS = new Set(["android", "ios"]);
const TIMEOUT_MS = 5000;
const MAX_ATTEMPTS = 10;

function envValue(name, fallback = "") {
  const value = String(process.env[name] || "").trim();
  return !value || value === "UNSET" ? fallback : value;
}

function netRevenue(gross) {
  const fee = Number(envValue("MMP_STORE_FEE", "0.15"));
  const rate = Number.isFinite(fee) && fee >= 0 && fee < 1 ? fee : 0.15;
  return Math.round(Number(gross || 0) * (1 - rate) * 100) / 100;
}

async function rememberDevice(uid, platform, mmpId) {
  const id = String(mmpId || "").trim();
  if (!uid || !PLATFORMS.has(platform) || !/^[\w.-]{6,64}$/.test(id)) return;
  const db = admin.firestore();
  await db.runTransaction(async (transaction) => {
    const [user, deleted] = await Promise.all([
      transaction.get(db.collection("Users").doc(uid)),
      transaction.get(db.collection("DeletedAccounts").doc(uid)),
    ]);
    if (!user.exists || deleted.exists) return;
    transaction.set(db.collection("MmpIds").doc(uid),
      { [platform]: { appsflyerId: id, em: admin.firestore.FieldValue.serverTimestamp() } },
      { merge: true });
  });
}

function eventTime(date = new Date()) {
  return date.toISOString().replace("T", " ").replace("Z", "");
}

/**
 * Nunca lança: falha no MMP não pode derrubar a confirmação da compra nem
 * fazer a loja reenviar a notificação. Devolve { sent, reason }.
 */
async function logServerRevenue({ uid, platform, transactionId, type, revenue, currency = "BRL", test = false }) {
  try {
    const url = envValue("MMP_S2S_URL");
    const token = envValue("MMP_S2S_TOKEN");
    const eventName = EVENT_NAMES[type];
    if (!url || !token) return { sent: false, reason: "desligado" };
    if (!eventName) return { sent: false, reason: "tipo_sem_receita" };
    if (test) return { sent: false, reason: "compra_de_teste" };
    if (!uid || !PLATFORMS.has(platform)) return { sent: false, reason: "sem_conta" };

    const devices = (await admin.firestore().collection("MmpIds").doc(uid).get()).data() || {};
    const appsflyerId = devices[platform]?.appsflyerId;
    if (!appsflyerId) return { sent: false, reason: "sem_aparelho" };

    const appId = platform === "ios"
      ? envValue("MMP_APP_ID_IOS")
      : envValue("MMP_APP_ID_ANDROID", "app.usepago");
    if (!appId) return { sent: false, reason: "sem_app_id" };

    const response = await fetch(url.replace("{app_id}", encodeURIComponent(appId)), {
      method: "POST",
      headers: { authentication: token, "content-type": "application/json" },
      body: JSON.stringify({
        appsflyer_id: appsflyerId,
        customer_user_id: uid,
        eventName,
        eventCurrency: currency,
        eventTime: eventTime(),
        eventValue: {
          af_revenue: revenue,
          af_currency: currency,
          af_order_id: transactionId || "",
          af_content_id: "premium_mensal",
        },
        af_events_api: "true",
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) {
      console.warn("MMP recusou a receita.", response.status, (await response.text()).slice(0, 200));
      return { sent: false, reason: `http_${response.status}` };
    }
    return { sent: true };
  } catch (error) {
    console.warn("MMP indisponível.", error.message);
    return { sent: false, reason: "erro" };
  }
}

function outboxKey(event) {
  return crypto.createHash("sha256").update(`${event.platform}:${event.transactionId}:${event.type}`).digest("hex");
}

// The business event and its delivery job commit together. Delivery is at
// least once: af_order_id remains stable so downstream reporting can reconcile
// duplicates when the remote response is lost after acceptance.
async function recordRevenueEvent(ref, data, event) {
  const db = admin.firestore();
  const enabled = !!envValue("MMP_S2S_URL") && !!envValue("MMP_S2S_TOKEN");
  return db.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) return false;
    let deleted = false;
    if (event?.uid) {
      deleted = (await transaction.get(db.collection("DeletedAccounts").doc(event.uid))).exists;
    }
    if (deleted) return false;
    transaction.create(ref, data);
    if (enabled && event && !event.test && event.uid && event.transactionId && EVENT_NAMES[event.type]) {
      transaction.create(db.collection("MmpOutbox").doc(outboxKey(event)), {
        ...event,
        state: "pending",
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        nextAttemptAt: admin.firestore.Timestamp.fromMillis(0),
      });
    }
    return true;
  });
}

async function flushRevenueEvent(eventOrRef) {
  const db = admin.firestore();
  const ref = eventOrRef.path ? eventOrRef : db.collection("MmpOutbox").doc(outboxKey(eventOrRef));
  const now = Date.now();
  const job = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) return null;
    const data = snap.data();
    const deleted = (await transaction.get(db.collection("DeletedAccounts").doc(data.uid))).exists;
    if (deleted) { transaction.delete(ref); return null; }
    if (!["pending", "processing"].includes(data.state)) return null;
    if ((data.nextAttemptAt?.toMillis?.() || 0) > now ||
        (data.lockedUntil?.toMillis?.() || 0) > now) return null;
    const attempts = (data.attempts || 0) + 1;
    transaction.update(ref, {
      state: "processing", attempts,
      lockedUntil: admin.firestore.Timestamp.fromMillis(now + 5 * 60 * 1000),
    });
    return { ...data, attempts };
  });
  if (!job) return;
  const result = await logServerRevenue(job);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const deleted = (await transaction.get(db.collection("DeletedAccounts").doc(job.uid))).exists;
    if (!snap.exists) return;
    if (deleted) { transaction.delete(ref); return; }
    transaction.update(ref, {
      state: result.sent ? "sent" : job.attempts >= MAX_ATTEMPTS ? "failed" : "pending",
      lastReason: result.sent ? null : result.reason,
      lockedUntil: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      nextAttemptAt: admin.firestore.Timestamp.fromMillis(Date.now() + Math.min(6 * 60 * 60 * 1000, 60000 * 2 ** job.attempts)),
    });
  });
}

async function flushRevenueOutbox() {
  const jobs = await admin.firestore().collection("MmpOutbox")
    .where("state", "in", ["pending", "processing"]).limit(100).get();
  for (const job of jobs.docs) await flushRevenueEvent(job.ref);
}

module.exports = {
  EVENT_NAMES,
  netRevenue,
  rememberDevice,
  logServerRevenue,
  recordRevenueEvent,
  flushRevenueEvent,
  flushRevenueOutbox,
};
