// Server-only reconciliation. Public Users fields remain compatible with older
// app versions; each store keeps its own source of truth in its collection.
const admin = require("firebase-admin");

const PLAY_ACTIVE = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);

function millis(value) {
  return value?.toMillis?.() || value?.getTime?.() || 0;
}

function activeSource(data, store, id) {
  if (!data.verificada || data.deletedAccount || data.replacedBy) return null;
  const expiry = millis(data.venceEm);
  const active = store === "play"
    ? PLAY_ACTIVE.has(data.estado) && (!data.productId || data.productId === "pago_premium_monthly")
    : data.estado === "ATIVA" && !data.revogada;
  if (!active || expiry <= Date.now()) return null;
  return { expiry, id: store === "play" ? `play_${id}` : `apple_${id}` };
}

function choosePremium(profile, sources) {
  const candidates = sources.filter(Boolean);
  const currentId = String(profile.premium_transaction_id || "");
  const currentExpiry = millis(profile.premium_vence_em);
  // Courtesy and legacy PIX are independent grants. A store cancellation must
  // not erase them. Store sources are recomputed from verified subscriptions.
  const courtesy = !currentId || currentId.startsWith("admin_") || currentId.startsWith("pay_");
  if (courtesy && profile.is_premium && currentExpiry > Date.now()) {
    candidates.push({ expiry: currentExpiry, id: profile.premium_transaction_id || null });
  }
  candidates.sort((a, b) => b.expiry - a.expiry || String(a.id).localeCompare(String(b.id)));
  const best = candidates[0];
  return {
    is_premium: !!best,
    premium_vence_em: best ? admin.firestore.Timestamp.fromMillis(best.expiry) : null,
    premium_transaction_id: best?.id || null,
  };
}

async function readAccount(transaction, db, uid) {
  const userRef = db.collection("Users").doc(uid);
  const [user, deleted, play, apple] = await Promise.all([
    transaction.get(userRef),
    transaction.get(db.collection("DeletedAccounts").doc(uid)),
    transaction.get(db.collection("PlaySubscriptions").where("uid", "==", uid)),
    transaction.get(db.collection("AppleSubscriptions").where("uid", "==", uid)),
  ]);
  return { userRef, profile: user.data() || {}, exists: user.exists && !deleted.exists, play, apple };
}

function sourcesFor(account, incomingStore, incomingId, incomingData) {
  const sources = [];
  for (const [store, query] of [["play", account.play], ["apple", account.apple]]) {
    for (const doc of query.docs) {
      if (store === incomingStore && doc.id === incomingId) continue;
      if (store === "play" && incomingStore === "play" && doc.id === incomingData.replacesTokenKey) continue;
      sources.push(activeSource(doc.data(), store, doc.id));
    }
  }
  sources.push(activeSource(incomingData, incomingStore, incomingId));
  return sources;
}

function accountUnavailable() {
  const error = new Error("Esta conta não está disponível. Entre de novo ou procure o suporte.");
  error.status = 410;
  return error;
}

module.exports = { activeSource, choosePremium, readAccount, sourcesFor, accountUnavailable };
