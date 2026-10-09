const { onRequest } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");

const adminEmailsParam = defineString("ADMIN_EMAILS", { default: "" });

const REGION = "southamerica-east1";
const PREMIUM_VALUE = 39.9;
const ONLINE_MS = 5 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_PREMIUM_DAYS = 366;
const OWNED_COLLECTIONS = [
  ["Debts", "user_id"],
  ["Payments", "user_id"],
  ["Bills", "user_id"],
  ["PremiumCharges", "userId"],
];

function adminEmails() {
  let raw = "";
  try {
    raw = adminEmailsParam.value();
  } catch (_) {
    raw = process.env.ADMIN_EMAILS || "";
  }
  return String(raw || "")
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

exports.adminApi = onRequest(
  { region: REGION, cors: true, invoker: "public", timeoutSeconds: 120, memory: "512MiB" },
  async (req, res) => {
    try {
      const caller = await requireAdmin(req);
      const route = String(req.path || "/").replace(/\/+$/, "") || "/";

      if (req.method === "GET" && route === "/overview") {
        res.status(200).json(await overview());
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ message: "Rota não encontrada." });
        return;
      }

      const uid = String(req.body?.uid || "").trim();
      if (!uid) {
        res.status(400).json({ message: "Informe a pessoa." });
        return;
      }

      if (route === "/premium") {
        const days = Number(req.body?.days || 30);
        if (!Number.isInteger(days) || days < 1 || days > MAX_PREMIUM_DAYS) {
          res.status(400).json({ message: "Dias inválidos (1 a 366)." });
          return;
        }
        res.status(200).json(await givePremium(uid, days));
        return;
      }
      if (route === "/revoke") {
        await revokePremium(uid);
        res.status(200).json({ ok: true });
        return;
      }
      if (route === "/delete") {
        if (uid === caller.uid) {
          res.status(400).json({ message: "Você não pode excluir a sua própria conta aqui." });
          return;
        }
        res.status(200).json(await deleteAccount(uid));
        return;
      }
      res.status(404).json({ message: "Rota não encontrada." });
    } catch (error) {
      res.status(error.status || 500).json({ message: error.message || "Erro no painel." });
    }
  },
);

async function requireAdmin(req) {
  const header = req.get("authorization") || "";
  const match = /^Bearer (.+)$/i.exec(header);
  if (!match) throw httpError(401, "Entre com a conta de administrador.");
  let token;
  try {
    token = await admin.auth().verifyIdToken(match[1]);
  } catch (_) {
    throw httpError(401, "Sessão expirada. Entre de novo.");
  }
  const email = String(token.email || "").toLowerCase();
  const allowed = adminEmails();
  if (!email || !allowed.includes(email)) {
    throw httpError(403, "Esta conta não é administradora.");
  }
  return token;
}

async function overview() {
  const db = admin.firestore();
  const [authUsers, profiles, presence] = await Promise.all([
    listAuthUsers(),
    db.collection("Users").get(),
    db.collection("Presence").get(),
  ]);

  const profileById = new Map(profiles.docs.map((doc) => [doc.id, doc.data()]));
  const seenById = new Map(
    presence.docs.map((doc) => [doc.id, doc.data()]),
  );
  const now = Date.now();
  const allowed = adminEmails();

  const users = authUsers.map((record) => {
    const profile = profileById.get(record.uid) || {};
    const seen = seenById.get(record.uid) || {};
    const premiumUntil = toMillis(profile.premium_vence_em);
    const lastSeen =
      toMillis(seen.last_seen_at) || Date.parse(record.metadata.lastSignInTime || "") || null;
    return {
      uid: record.uid,
      nome: profile.nome || record.displayName || "",
      email: record.email || profile.email || "",
      telefone: profile.telefone || "",
      criadoEm: Date.parse(record.metadata.creationTime || "") || null,
      ultimoAcesso: lastSeen,
      plataforma: seen.plataforma || "",
      premiumAte: premiumUntil,
      premiumAtivo: profile.is_premium === true && !!premiumUntil && premiumUntil > now,
      premiumOrigem: premiumOrigin(profile.premium_transaction_id),
      admin: allowed.includes(String(record.email || "").toLowerCase()),
      desativado: record.disabled === true,
    };
  });

  await attachCounts(users);
  users.sort((a, b) => (b.ultimoAcesso || 0) - (a.ultimoAcesso || 0));

  const people = users.filter((user) => !user.admin);
  const premium = people.filter((user) => user.premiumAtivo);
  const paying = premium.filter((user) => user.premiumOrigem !== "admin");
  const activeSince = (ms) => people.filter((user) => user.ultimoAcesso && now - user.ultimoAcesso <= ms).length;

  const signups = [];
  for (let i = 13; i >= 0; i -= 1) {
    const start = startOfDay(now - i * DAY_MS);
    const end = start + DAY_MS;
    signups.push({
      dia: start,
      total: people.filter((user) => user.criadoEm && user.criadoEm >= start && user.criadoEm < end).length,
    });
  }

  return {
    geradoEm: now,
    stats: {
      total: people.length,
      novos7d: people.filter((user) => user.criadoEm && now - user.criadoEm <= 7 * DAY_MS).length,
      online: activeSince(ONLINE_MS),
      ativos24h: activeSince(DAY_MS),
      ativos7d: activeSince(7 * DAY_MS),
      ativos30d: activeSince(30 * DAY_MS),
      premium: premium.length,
      premiumPagantes: paying.length,
      premiumCortesia: premium.length - paying.length,
      premiumVence7d: premium.filter((user) => user.premiumAte - now <= 7 * DAY_MS).length,
      receitaEstimada: Math.round(paying.length * PREMIUM_VALUE * 100) / 100,
      cadastros14d: signups,
    },
    users,
  };
}

async function listAuthUsers() {
  const all = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    all.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return all;
}

async function attachCounts(users) {
  const db = admin.firestore();
  const countOf = async (collection, uid) => {
    const snap = await db.collection(collection).where("user_id", "==", uid).count().get();
    return snap.data().count;
  };
  for (let i = 0; i < users.length; i += 20) {
    await Promise.all(
      users.slice(i, i + 20).map(async (user) => {
        try {
          const [lancamentos, pagamentos, boletos] = await Promise.all([
            countOf("Debts", user.uid),
            countOf("Payments", user.uid),
            countOf("Bills", user.uid),
          ]);
          user.uso = { lancamentos, pagamentos, boletos };
        } catch (_) {
          user.uso = null;
        }
      }),
    );
  }
}

async function givePremium(uid, days) {
  await admin.auth().getUser(uid).catch(() => {
    throw httpError(404, "Pessoa não encontrada.");
  });
  const ref = admin.firestore().collection("Users").doc(uid);
  const snap = await ref.get();
  const current = toMillis(snap.data()?.premium_vence_em);
  const active = snap.data()?.is_premium === true && current && current > Date.now();
  const base = active ? current : Date.now();
  const until = new Date(base + days * DAY_MS);
  await ref.set(
    {
      is_premium: true,
      premium_vence_em: admin.firestore.Timestamp.fromDate(until),
      premium_transaction_id: `admin_${days}d_${Date.now()}`,
    },
    { merge: true },
  );
  return { ok: true, premiumAte: until.getTime() };
}

async function revokePremium(uid) {
  await admin.firestore().collection("Users").doc(uid).set(
    {
      is_premium: false,
      premium_vence_em: null,
      premium_transaction_id: null,
    },
    { merge: true },
  );
}

async function deleteAccount(uid) {
  let record = null;
  try {
    record = await admin.auth().getUser(uid);
  } catch (_) {
    record = null;
  }
  if (record && adminEmails().includes(String(record.email || "").toLowerCase())) {
    throw httpError(400, "Não dá para excluir uma conta administradora.");
  }

  const db = admin.firestore();
  let removed = 0;
  for (const [collection, field] of OWNED_COLLECTIONS) {
    removed += await deleteWhere(db.collection(collection).where(field, "==", uid));
  }
  await db.collection("Users").doc(uid).delete();
  await db.collection("Presence").doc(uid).delete();
  if (record) await admin.auth().deleteUser(uid);
  return { ok: true, documentos: removed };
}

async function deleteWhere(query) {
  let total = 0;
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return total;
    const batch = admin.firestore().batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    total += snap.size;
  }
}

function premiumOrigin(transactionId) {
  const id = String(transactionId || "");
  if (!id) return "";
  if (id.startsWith("admin_")) return "admin";
  if (id.startsWith("pay_")) return "pix";
  return "play";
}

function toMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function startOfDay(ms) {
  const offset = 3 * 60 * 60 * 1000;
  const local = new Date(ms - offset);
  local.setUTCHours(0, 0, 0, 0);
  return local.getTime() + offset;
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}
