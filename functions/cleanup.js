// Limpeza automática (opcional) de cadernetas quitadas. Só roda para quem ligou
// "limpeza_auto" em Mais. Uma caderneta é o conjunto de lançamentos de um
// mesmo cliente; ela só entra quando TODOS os lançamentos estão quitados, o
// último pagamento tem pelo menos 7 dias e o cliente não foi marcado como
// "manter". O app avisa o dono antes (contagem regressiva no contato).
const admin = require("firebase-admin");

const DAY_MS = 24 * 60 * 60 * 1000;
const RETENTION_DAYS = 7;
const BATCH = 400;

const db = () => admin.firestore();

function toMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = typeof value === "number" ? value : Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

const FROM = "áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ";
const TO = "aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN";

// Mesma chave de contato do app (client_match.dart: contactKeyOf).
function contactKey(debt) {
  const phone = String(debt.telefone || "").replace(/\D/g, "");
  if (phone.length >= 10) return `p:${phone}`;
  let name = "";
  for (const char of String(debt.nome || "").trim().toLowerCase()) {
    const index = FROM.indexOf(char);
    name += index === -1 ? char : TO[index];
  }
  return `n:${name.replace(/\s+/g, " ")}`;
}

/**
 * @param {{id: string, data: object}[]} debts lançamentos de UM usuário
 * @param {{debt_id: string, data: any, estornado_em?: any}[]} payments
 * @returns {{key: string, debtIds: string[], paymentIds: string[]}[]}
 */
function planCleanup({ debts, payments, now }) {
  const groups = new Map();
  for (const debt of debts) {
    const key = contactKey(debt.data);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(debt);
  }
  const plan = [];
  for (const [key, list] of groups) {
    if (!list.every((d) => d.data.status_pago === true)) continue;
    if (list.some((d) => d.data.manter === true)) continue;
    const ids = new Set(list.map((d) => d.id));
    const own = payments.filter((p) => ids.has(p.data.debt_id));
    let closedAt = 0;
    for (const p of own) {
      if (p.data.estornado_em) continue;
      closedAt = Math.max(closedAt, toMillis(p.data.data) || 0);
    }
    if (!closedAt) {
      for (const d of list) {
        closedAt = Math.max(
          closedAt,
          toMillis(d.data.created_at) || 0,
          toMillis(d.data.data_vencimento) || 0,
        );
      }
    }
    if (!closedAt || now - closedAt < RETENTION_DAYS * DAY_MS) continue;
    plan.push({
      key,
      debtIds: list.map((d) => d.id),
      paymentIds: own.map((p) => p.id),
    });
  }
  return plan;
}

async function deleteAll(refs) {
  for (let i = 0; i < refs.length; i += BATCH) {
    const batch = db().batch();
    for (const ref of refs.slice(i, i + BATCH)) batch.delete(ref);
    await batch.commit();
  }
}

async function runCleanup(now = Date.now()) {
  const users = await db().collection("Users").where("limpeza_auto", "==", true).get();
  let removed = 0;
  for (const user of users.docs) {
    const [debtSnap, paySnap] = await Promise.all([
      db().collection("Debts").where("user_id", "==", user.id).get(),
      db().collection("Payments").where("user_id", "==", user.id).get(),
    ]);
    const debts = debtSnap.docs.map((d) => ({ id: d.id, ref: d.ref, data: d.data() }));
    const payments = paySnap.docs.map((d) => ({ id: d.id, ref: d.ref, data: d.data() }));
    const plan = planCleanup({ debts, payments, now });
    const byId = new Map([...debts, ...payments].map((d) => [d.id, d.ref]));
    for (const item of plan) {
      await deleteAll([...item.paymentIds, ...item.debtIds].map((id) => byId.get(id)));
      removed += item.debtIds.length;
    }
  }
  return removed;
}

module.exports = { planCleanup, contactKey, runCleanup, RETENTION_DAYS };
