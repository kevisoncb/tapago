const crypto = require("crypto");

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const webhookToken = defineSecret("ASAAS_WEBHOOK_TOKEN");

const PAID_EVENTS = new Set([
  "PAYMENT_CONFIRMED",
  "PAYMENT_RECEIVED",
  "PAYMENT_RECEIVED_IN_CASH",
]);

const PAID_STATUS = new Set(["CONFIRMED", "RECEIVED", "RECEIVED_IN_CASH"]);

exports.asaasWebhook = onRequest(
  {
    region: "southamerica-east1",
    secrets: [webhookToken],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const expected = webhookToken.value();
    const received = req.get("asaas-access-token") || "";
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

    const expires = new Date();
    expires.setDate(expires.getDate() + 30);

    await admin.firestore().collection("Users").doc(userId).set(
      {
        is_premium: true,
        premium_vence_em: admin.firestore.Timestamp.fromDate(expires),
        premium_transaction_id: payment.id || null,
      },
      { merge: true },
    );

    res.status(200).json({ ok: true, userId });
  },
);

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
