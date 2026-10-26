const crypto = require("crypto");

const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");

const mmp = require("./mmp_s2s");
const rights = require("./subscription_rights");

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
  const premiumItems = items.filter((line) => line.productId === PRODUCT_ID);
  const item = premiumItems.reduce((best, line) =>
    (Date.parse(line.expiryTime || "") || 0) > (Date.parse(best?.expiryTime || "") || 0) ? line : best, null) || {};
  const expiry = Date.parse(item.expiryTime || "") || 0;
  const money = item.autoRenewingPlan?.recurringPrice;
  const price = money ? Number(money.units || 0) + Number(money.nanos || 0) / 1e9 : DEFAULT_PRICE;
  return {
    productId: item.productId || "",
    state: sub?.subscriptionState || "",
    expiry: expiry || null,
    orderId: sub?.latestOrderId || "",
    price: Math.round(price * 100) / 100,
    autoRenew: item.autoRenewingPlan?.autoRenewEnabled === true,
    uid: sub?.externalAccountIdentifiers?.obfuscatedExternalAccountId || "",
    linkedPurchaseToken: sub?.linkedPurchaseToken || "",
    test: !!sub?.testPurchase,
  };
}

function isActive(summary) {
  return summary.productId === PRODUCT_ID && ACTIVE_STATES.has(summary.state) &&
    !!summary.expiry && summary.expiry > Date.now();
}

function tokenKey(purchaseToken) {
  return crypto.createHash("sha256").update(purchaseToken).digest("hex").slice(0, 40);
}

async function applySubscription(uid, purchaseToken, summary) {
  const db = admin.firestore();
  if (summary.productId !== PRODUCT_ID) {
    const error = new Error("Esta compra não é o Pagô Premium.");
    error.status = 400;
    throw error;
  }
  if (summary.uid && summary.uid !== uid) throw ownerMismatch();
  const active = isActive(summary);
  const key = tokenKey(purchaseToken);
  const ref = db.collection("PlaySubscriptions").doc(key);
  const linkedKey = summary.linkedPurchaseToken ? tokenKey(summary.linkedPurchaseToken) : null;
  const linkedRef = linkedKey && linkedKey !== key ? db.collection("PlaySubscriptions").doc(linkedKey) : null;
  return db.runTransaction(async (transaction) => {
    const [storedSnap, account, linkedSnap] = await Promise.all([
      transaction.get(ref), rights.readAccount(transaction, db, uid),
      linkedRef ? transaction.get(linkedRef) : null,
    ]);
    const stored = storedSnap.data() || {};
    if (stored.uid && stored.uid !== uid) throw ownerMismatch();
    if (!summary.uid && stored.uid !== uid) throw ownerMismatch();
    if (linkedSnap?.data()?.uid && linkedSnap.data().uid !== uid) throw ownerMismatch();
    if (stored.deletedAccount || !account.exists) throw rights.accountUnavailable();
    const data = {
      uid,
      purchaseToken,
      productId: PRODUCT_ID,
      replacesTokenKey: linkedKey,
      verificada: true,
      estado: summary.state,
      venceEm: summary.expiry ? admin.firestore.Timestamp.fromMillis(summary.expiry) : null,
      orderId: summary.orderId,
      valor: summary.price,
      renovaSozinha: summary.autoRenew,
      teste: summary.test,
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    };
    transaction.set(ref, data, { merge: true });
    if (linkedSnap?.exists) transaction.update(linkedRef, { replacedBy: key });
    transaction.update(account.userRef,
      rights.choosePremium(account.profile, rights.sourcesFor(account, "play", key, data)));
    return active;
  });
}

function ownerMismatch() {
  const error = new Error("Esta assinatura pertence a outra conta do Pagô.");
  error.status = 403;
  return error;
}

async function uidForToken(purchaseToken, summary) {
  const snap = await admin.firestore().collection("PlaySubscriptions").doc(tokenKey(purchaseToken)).get();
  const stored = snap.data() || {};
  if (stored.deletedAccount) return "";
  if (summary?.uid && stored.uid && summary.uid !== stored.uid) throw ownerMismatch();
  return stored.uid || summary?.uid || "";
}

async function logPlayEvent(uid, type, summary) {
  const charge = CHARGE_TYPES.has(type);
  const base = summary.orderId || `sem_pedido_${Date.now()}`;
  const id = (charge ? base : `${base}_${type}`).replace(/[^\w.-]/g, "_");
  const revenueEvent = charge && !summary.unverified ? {
    uid, platform: "android", transactionId: summary.orderId, type,
    revenue: mmp.netRevenue(summary.price), test: summary.test === true,
  } : null;
  const created = await mmp.recordRevenueEvent(admin.firestore().collection("PlayEvents").doc(id), {
      uid: uid || null,
      tipo: type,
      cobranca: charge,
      valor: charge ? summary.price : 0,
      orderId: summary.orderId || "",
      teste: summary.test === true,
      em: admin.firestore.FieldValue.serverTimestamp(),
    }, revenueEvent);
  if (created && revenueEvent) {
    try { await mmp.flushRevenueEvent(revenueEvent); }
    catch (_) { console.warn("Receita da Play permanece na fila para nova tentativa."); }
  }
  return created;
}

module.exports = {
  NOTIFICATION_TYPES,
  PACKAGE_NAME,
  PRODUCT_ID,
  fetchSubscription,
  summarize,
  isActive,
  applySubscription,
  uidForToken,
  logPlayEvent,
};
