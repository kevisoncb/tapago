const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const admin = require("firebase-admin");
const {
  APIError,
  APIException,
  AppStoreServerAPIClient,
  Environment,
  NotificationTypeV2,
  SignedDataVerifier,
  VerificationException,
} = require("@apple/app-store-server-library");

const mmp = require("./mmp_s2s");

const PRODUCT_ID = "pago_premium_monthly_ios";
const DEFAULT_BUNDLE_ID = "app.usepago";
const DEFAULT_PRICE = 39.9;

// Tem que ser igual a appAccountTokenFor() em lib/services/store_ids.dart.
const ACCOUNT_TOKEN_NAMESPACE = Buffer.from("6ba7b8119dad11d180b400c04fd430c8", "hex");
const ACCOUNT_TOKEN_PREFIX = "https://usepago.app/uid/";

// Raízes públicas da Apple (apple.com/certificateauthority). O verificador só
// aceita JWS cuja cadeia x5c termine numa delas.
const ROOT_CERTIFICATES = fs
  .readdirSync(path.join(__dirname, "certs"))
  .filter((name) => name.endsWith(".cer"))
  .map((name) => fs.readFileSync(path.join(__dirname, "certs", name)));

const CHARGE_TYPES = new Set(["COMPRA", "RENOVADA", "RECUPERADA"]);
const FORCE_INACTIVE = new Set([
  NotificationTypeV2.EXPIRED,
  NotificationTypeV2.GRACE_PERIOD_EXPIRED,
  NotificationTypeV2.REFUND,
  NotificationTypeV2.REVOKE,
]);

/**
 * Variáveis em functions/.env (gitignored), lidas em tempo de execução:
 *   APPLE_ISSUER_ID   App Store Connect → Usuários e acesso → Integrações → Issuer ID
 *   APPLE_KEY_ID      ID da chave "In-App Purchase" gerada na mesma tela
 *   APPLE_PRIVATE_KEY conteúdo do .p8 (PEM com \n escapado, ou o arquivo inteiro em base64)
 *   APPLE_APP_ID      Apple ID numérico do app (App Store Connect → Informações do app)
 *   APPLE_BUNDLE_ID   opcional, padrão app.usepago
 * Sem APPLE_APP_ID só transações de Sandbox são aceitas (exigência da biblioteca).
 * Sem ISSUER/KEY/PRIVATE_KEY a compra é conferida só pela assinatura do JWS que o app envia.
 */
function config() {
  return {
    issuerId: envValue("APPLE_ISSUER_ID"),
    keyId: envValue("APPLE_KEY_ID"),
    privateKey: decodePrivateKey(envValue("APPLE_PRIVATE_KEY")),
    bundleId: envValue("APPLE_BUNDLE_ID") || DEFAULT_BUNDLE_ID,
    appAppleId: Number(envValue("APPLE_APP_ID")) || undefined,
  };
}

function envValue(name) {
  const value = String(process.env[name] || "").trim();
  return value === "UNSET" ? "" : value;
}

function decodePrivateKey(raw) {
  if (!raw) return "";
  if (raw.includes("BEGIN PRIVATE KEY")) return raw.replace(/\\n/g, "\n");
  return Buffer.from(raw, "base64").toString("utf8");
}

function hasApiCredentials() {
  const { issuerId, keyId, privateKey } = config();
  return !!(issuerId && keyId && privateKey);
}

let verifiers;
let apiClients;

/** Produção primeiro; Sandbox sempre, porque a revisão da Apple compra em Sandbox no app de produção. */
function getVerifiers() {
  if (verifiers) return verifiers;
  const { bundleId, appAppleId } = config();
  verifiers = [];
  if (appAppleId) {
    verifiers.push(new SignedDataVerifier(ROOT_CERTIFICATES, true, Environment.PRODUCTION, bundleId, appAppleId));
  }
  verifiers.push(new SignedDataVerifier(ROOT_CERTIFICATES, true, Environment.SANDBOX, bundleId));
  return verifiers;
}

function getApiClients() {
  if (apiClients) return apiClients;
  const { issuerId, keyId, privateKey, bundleId } = config();
  apiClients = [Environment.PRODUCTION, Environment.SANDBOX].map(
    (environment) => new AppStoreServerAPIClient(privateKey, keyId, issuerId, bundleId, environment),
  );
  return apiClients;
}

/**
 * Confere assinatura ES256, cadeia até a raiz da Apple (com checagem OCSP),
 * bundle ID e ambiente. Falha em todos os ambientes = JWS inválido.
 */
async function verify(decode) {
  let lastError;
  for (const verifier of getVerifiers()) {
    try {
      return await decode(verifier);
    } catch (error) {
      if (!(error instanceof VerificationException)) throw error;
      lastError = error;
    }
  }
  throw httpError(400, "Assinatura da Apple inválida.", lastError);
}

const decodeTransaction = (jws) => verify((v) => v.verifyAndDecodeTransaction(jws));
const decodeRenewalInfo = (jws) => verify((v) => v.verifyAndDecodeRenewalInfo(jws));
const decodeNotification = (jws) => verify((v) => v.verifyAndDecodeNotification(jws));

/** App Store Server API: Produção e, se a transação não existir lá, Sandbox (orientação da Apple). */
async function fetchSignedTransaction(transactionId) {
  for (const client of getApiClients()) {
    try {
      const response = await client.getTransactionInfo(transactionId);
      if (response.signedTransactionInfo) return response.signedTransactionInfo;
    } catch (error) {
      const notHere =
        error instanceof APIException &&
        (error.apiError === APIError.TRANSACTION_ID_NOT_FOUND ||
          error.apiError === APIError.INVALID_TRANSACTION_ID);
      if (!notHere) throw error;
    }
  }
  throw httpError(404, "A App Store não encontrou esta compra.");
}

function accountTokenFor(uid) {
  const hash = crypto
    .createHash("sha1")
    .update(ACCOUNT_TOKEN_NAMESPACE)
    .update(`${ACCOUNT_TOKEN_PREFIX}${uid}`, "utf8")
    .digest()
    .subarray(0, 16);
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = hash.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function summarize(tx, { forceInactive = false, autoRenew = null } = {}) {
  const expiry = Number(tx.expiresDate) || null;
  const revoked = !!tx.revocationDate;
  return {
    originalTransactionId: String(tx.originalTransactionId || ""),
    transactionId: String(tx.transactionId || ""),
    orderId: String(tx.transactionId || ""),
    expiry,
    revoked,
    active: !forceInactive && !revoked && !!expiry && expiry > Date.now(),
    price: tx.price ? Math.round(tx.price / 10) / 100 : DEFAULT_PRICE,
    currency: tx.currency || "BRL",
    autoRenew,
    test: tx.environment !== Environment.PRODUCTION,
  };
}

function subscriptionRef(originalTransactionId) {
  return admin.firestore().collection("AppleSubscriptions").doc(originalTransactionId);
}

function premiumId(originalTransactionId) {
  return `apple_${originalTransactionId}`.slice(0, 120);
}

/**
 * Grava AppleSubscriptions/{originalTransactionId} e o Premium em Users/{uid}.
 * Notificações chegam fora de ordem: uma transação com validade menor que a
 * gravada é ignorada (salvo estorno/revogação/expiração). Desligar o Premium só
 * mexe no usuário se o Premium atual veio desta assinatura (não apaga cortesia
 * do painel nem assinatura da Play).
 */
async function applyTransaction(uid, tx, options = {}) {
  const db = admin.firestore();
  const summary = summarize(tx, options);
  const ref = subscriptionRef(summary.originalTransactionId);
  return db.runTransaction(async (t) => {
    const stored = (await t.get(ref)).data() || {};
    const owner = uid || stored.uid || null;
    const userRef = owner ? db.collection("Users").doc(owner) : null;
    const profile = userRef ? (await t.get(userRef)).data() || {} : {};

    const storedExpiry = stored.venceEm?.toMillis?.() || 0;
    if (!options.forceInactive && summary.expiry && summary.expiry < storedExpiry) {
      if (owner && !stored.uid) t.set(ref, { uid: owner }, { merge: true });
      return { ...summary, uid: owner, stale: true };
    }

    t.set(
      ref,
      {
        uid: owner,
        appAccountToken: tx.appAccountToken || stored.appAccountToken || null,
        productId: tx.productId || PRODUCT_ID,
        ultimaTransacao: summary.transactionId,
        estado: summary.active ? "ATIVA" : summary.revoked ? "REVOGADA" : "INATIVA",
        venceEm: summary.expiry ? admin.firestore.Timestamp.fromMillis(summary.expiry) : null,
        revogada: summary.revoked,
        valor: summary.price,
        moeda: summary.currency,
        ...(summary.autoRenew === null ? {} : { renovaSozinha: summary.autoRenew }),
        teste: summary.test,
        verificada: true,
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const ours = premiumId(summary.originalTransactionId);
    if (userRef && (summary.active || profile.premium_transaction_id === ours)) {
      t.set(
        userRef,
        {
          is_premium: summary.active,
          premium_vence_em: summary.expiry && !summary.revoked
            ? admin.firestore.Timestamp.fromMillis(summary.expiry)
            : null,
          premium_transaction_id: ours,
        },
        { merge: true },
      );
    }
    return { ...summary, uid: owner, stale: false };
  });
}

/**
 * POST /api/apple/confirm (usuário logado). Corpo: { transactionId, signedTransaction }.
 * 1. Com credenciais: busca a transação na App Store Server API (fonte da verdade).
 *    Sem credenciais ou Apple fora do ar: usa o JWS que o StoreKit 2 entregou ao app.
 * 2. Verifica o JWS (assinatura, cadeia, bundle, ambiente).
 * 3. Produto tem que ser pago_premium_monthly_ios.
 * 4. Dono: appAccountToken tem que ser o UUID v5 deste uid; se a assinatura já
 *    estiver ligada a outro uid, recusa (mesma regra da Play).
 * 5. Só libera se ativa (vence no futuro e sem estorno).
 */
async function confirmPurchase(uid, { transactionId, signedTransaction }) {
  let signed = "";
  if (transactionId && hasApiCredentials()) {
    try {
      signed = await fetchSignedTransaction(transactionId);
    } catch (error) {
      if (!signedTransaction || error.status === 404) throw error;
      console.warn("App Store Server API indisponível; conferindo o JWS do app.", error.message);
    }
  }
  signed ||= signedTransaction;
  if (!signed) throw httpError(400, "Atualize o app para confirmar a assinatura.");

  const tx = await decodeTransaction(signed);
  if (transactionId && ![tx.transactionId, tx.originalTransactionId].includes(transactionId)) {
    throw httpError(400, "A compra enviada não confere com a App Store.");
  }
  if (tx.productId !== PRODUCT_ID) {
    throw httpError(400, "Esta compra não é o Pagô Premium.");
  }
  const token = String(tx.appAccountToken || "").toLowerCase();
  if (token && token !== accountTokenFor(uid)) {
    throw httpError(403, "Esta assinatura pertence a outra conta do Pagô.");
  }
  const linked = (await subscriptionRef(String(tx.originalTransactionId)).get()).data()?.uid;
  if (linked && linked !== uid) {
    throw httpError(403, "Esta assinatura pertence a outra conta do Pagô.");
  }
  if (!summarize(tx).active) {
    throw httpError(402, "A App Store não mostra esta assinatura como ativa.");
  }

  const summary = await applyTransaction(uid, tx);
  const firstPurchase = tx.transactionId === tx.originalTransactionId;
  const created = firstPurchase ? await logAppleEvent(uid, "COMPRA", summary) : false;
  return { summary, created };
}

/**
 * POST /api/apple/notifications (App Store Server Notifications V2).
 * Sem login: a autenticidade vem só do JWS em { signedPayload }, verificado
 * antes de qualquer gravação. Resposta 200 encerra; qualquer outra faz a Apple
 * reenviar (até 5 vezes em 3 dias), por isso erro interno sobe como 500.
 */
async function handleNotification(signedPayload) {
  if (!signedPayload) throw httpError(400, "Sem signedPayload.");
  const notification = await decodeNotification(signedPayload);
  const { notificationType: type, subtype, data } = notification;
  if (type === NotificationTypeV2.TEST) return { type, ignored: true };
  if (!data?.signedTransactionInfo) return { type, ignored: true };

  const tx = await decodeTransaction(data.signedTransactionInfo);
  if (tx.productId !== PRODUCT_ID) return { type, ignored: true };
  const renewal = data.signedRenewalInfo ? await decodeRenewalInfo(data.signedRenewalInfo) : null;

  const summary = await applyTransaction(null, tx, {
    forceInactive: FORCE_INACTIVE.has(type),
    autoRenew: renewal ? renewal.autoRenewStatus === 1 : null,
  });
  const tipo = eventType(type, subtype);
  const created = await logAppleEvent(summary.uid, tipo, summary);
  return { type, subtype, tipo, uid: summary.uid, summary, created };
}

function eventType(type, subtype) {
  switch (type) {
    case NotificationTypeV2.SUBSCRIBED:
      return "COMPRA";
    case NotificationTypeV2.DID_RENEW:
      return subtype === "BILLING_RECOVERY" ? "RECUPERADA" : "RENOVADA";
    case NotificationTypeV2.EXPIRED:
    case NotificationTypeV2.GRACE_PERIOD_EXPIRED:
      return "EXPIRADA";
    case NotificationTypeV2.REFUND:
      return "ESTORNADA";
    case NotificationTypeV2.REVOKE:
      return "REVOGADA";
    case NotificationTypeV2.DID_FAIL_TO_RENEW:
      return subtype === "GRACE_PERIOD" ? "PERIODO_DE_CARENCIA" : "SUSPENSA";
    case NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS:
      return subtype === "AUTO_RENEW_DISABLED" ? "CANCELADA" : "REATIVADA";
    default:
      return `APPLE_${type}`;
  }
}

/** Mesma coleção da Play (o painel soma a receita dali), com loja "app_store". */
async function logAppleEvent(uid, type, summary) {
  const charge = CHARGE_TYPES.has(type);
  const base = `apple_${summary.transactionId || Date.now()}`;
  const id = (charge ? base : `${base}_${type}`).replace(/[^\w.-]/g, "_");
  try {
    await admin.firestore().collection("PlayEvents").doc(id).create({
      uid: uid || null,
      tipo: type,
      cobranca: charge,
      valor: charge ? summary.price : 0,
      orderId: summary.transactionId,
      loja: "app_store",
      teste: summary.test === true,
      em: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (charge) {
      await mmp.logServerRevenue({
        uid,
        platform: "ios",
        transactionId: summary.transactionId,
        type,
        revenue: mmp.netRevenue(summary.price),
        currency: summary.currency,
        test: summary.test,
      });
    }
    return true;
  } catch (error) {
    if (error.code === 6) return false;
    throw error;
  }
}

function httpError(status, message, cause) {
  const error = new Error(message);
  error.status = status;
  if (cause) error.cause = cause;
  return error;
}

module.exports = {
  PRODUCT_ID,
  accountTokenFor,
  confirmPurchase,
  handleNotification,
};
