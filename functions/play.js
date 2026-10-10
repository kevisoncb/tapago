const crypto = require("crypto");

const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");

const PACKAGE_NAME = "app.usepago";
const PRODUCT_ID = "pago_premium_monthly";
const DEFAULT_PRICE = 39.9;
const PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher";

const NOTIFICATION_TYPES = {
  1: "RECUPERADA",
  2: "RENOVADA",
  3: "CANCELADA",
  4: "COMPRA",
  5: "SUSPENSA",
  6: "PERIODO_DE_CARENCIA",
  7: "REATIVADA",
  8: "PRECO_ACEITO",
  9: "ADIADA",
  10: "PAUSADA",
  11: "PAUSA_AGENDADA",
  12: "ESTORNADA",
  13: "EXPIRADA",
  20: "PENDENTE_CANCELADA",
};

const CHARGE_TYPES = new Set(["COMPRA", "RENOVADA", "RECUPERADA"]);
const ACTIVE_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);

let authClient;

async function fetchSubscription(purchaseToken) {
  authClient ||= await new GoogleAuth({ scopes: [PUBLISHER_SCOPE] }).getClient();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await authClient.request({ url });
  return summarize(response.data);
}

function summarize(sub) {
  const items = Array.isArray(sub?.lineItems) ? sub.lineItems : [];
  const item = items.find((line) => line.productId === PRODUCT_ID) || items[0] || {};
  const expiry = Math.max(0, ...items.map((line) => Date.parse(line.expiryTime || "") || 0));
  const money = item.autoRenewingPlan?.recurringPrice;
  const price = money ? Number(money.units || 0) + Number(money.nanos || 0) / 1e9 : DEFAULT_PRICE;
  return {
    state: sub?.subscriptionState || "",
    expiry: expiry || null,
    orderId: sub?.latestOrderId || "",
    price: Math.round(price * 100) / 100,
    autoRenew: item.autoRenewingPlan?.autoRenewEnabled === true,
    uid: sub?.externalAccountIdentifiers?.obfuscatedExternalAccountId || "",
    test: !!sub?.testPurchase,
  };
}

function isActive(summary) {
  return ACTIVE_STATES.has(summary.state) && !!summary.expiry && summary.expiry > Date.now();
}

function tokenKey(purchaseToken) {
  return crypto.createHash("sha256").update(purchaseToken).digest("hex").slice(0, 40);
}

async function applySubscription(uid, purchaseToken, summary) {
  const db = admin.firestore();
  const active = isActive(summary);
  await db.collection("PlaySubscriptions").doc(tokenKey(purchaseToken)).set(
    {
      uid,
      purchaseToken,
      verificada: true,
      estado: summary.state,
      venceEm: summary.expiry ? admin.firestore.Timestamp.fromMillis(summary.expiry) : null,
      orderId: summary.orderId,
      valor: summary.price,
      renovaSozinha: summary.autoRenew,
      teste: summary.test,
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await db.collection("Users").doc(uid).set(
    {
      is_premium: active,
      premium_vence_em: summary.expiry ? admin.firestore.Timestamp.fromMillis(summary.expiry) : null,
      premium_transaction_id: (summary.orderId || `play_${tokenKey(purchaseToken).slice(0, 16)}`).slice(0, 120),
    },
    { merge: true },
  );
  return active;
}

async function linkUnverified(uid, purchaseToken, transactionId) {
  await admin.firestore().collection("PlaySubscriptions").doc(tokenKey(purchaseToken)).set(
    {
      uid,
      purchaseToken,
      verificada: false,
      orderId: transactionId || "",
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function uidForToken(purchaseToken, summary) {
  if (summary?.uid) return summary.uid;
  const snap = await admin.firestore().collection("PlaySubscriptions").doc(tokenKey(purchaseToken)).get();
  return snap.data()?.uid || "";
}

async function logPlayEvent(uid, type, summary) {
  const charge = CHARGE_TYPES.has(type);
  const base = summary.orderId || `sem_pedido_${Date.now()}`;
  const id = (charge ? base : `${base}_${type}`).replace(/[^\w.-]/g, "_");
  try {
    await admin.firestore().collection("PlayEvents").doc(id).create({
      uid: uid || null,
      tipo: type,
      cobranca: charge,
      valor: charge ? summary.price : 0,
      orderId: summary.orderId || "",
      teste: summary.test === true,
      em: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (error) {
    if (error.code === 6) return false;
    throw error;
  }
}

module.exports = {
  NOTIFICATION_TYPES,
  PACKAGE_NAME,
  fetchSubscription,
  summarize,
  isActive,
  applySubscription,
  linkUnverified,
  uidForToken,
  logPlayEvent,
};
