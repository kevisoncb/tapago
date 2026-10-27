// Lembretes de cobrança enviados pelo servidor (push), todo dia às 9h de Brasília,
// para todos os usuários. O texto leva só contagens: nada de nome, valor ou chave PIX.
const crypto = require("crypto");
const admin = require("firebase-admin");

const DAY_MS = 24 * 60 * 60 * 1000;
// Brasília não tem horário de verão desde 2019; o fuso é fixo em UTC-3.
const BRT_OFFSET_MS = -3 * 60 * 60 * 1000;
const IN_LIMIT = 30;
const SEND_LIMIT = 500;
const BAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

const db = () => admin.firestore();

function startOfDayBrt(ms) {
  return Math.floor((ms + BRT_OFFSET_MS) / DAY_MS) * DAY_MS - BRT_OFFSET_MS;
}

function dayId(ms) {
  return new Date(ms + BRT_OFFSET_MS).toISOString().slice(0, 10);
}

function toMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = typeof value === "number" ? value : Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function hasPremium(profile, now) {
  const until = toMillis(profile.premium_vence_em);
  return profile.is_premium === true && !!until && until > now;
}

function emptyCounts() {
  return {
    cobrancasHoje: 0, cobrancasAmanha: 0, cobrancasAtraso: 0,
    boletosTresDias: 0, boletosAmanha: 0, boletosHoje: 0, boletosAtraso: 0,
    contatosHoje: 0,
  };
}

/** Texto único por usuário, só com contagens. Retorna null quando não há nada para avisar. */
function buildReminder(c) {
  const n = (count, one, many) => `${count} ${count === 1 ? one : many}`;
  const parts = [];
  if (c.cobrancasHoje) parts.push(`${n(c.cobrancasHoje, "cobrança vence", "cobranças vencem")} hoje`);
  if (c.cobrancasAtraso) parts.push(`${n(c.cobrancasAtraso, "cobrança em atraso", "cobranças em atraso")}`);
  if (c.cobrancasAmanha) parts.push(`${n(c.cobrancasAmanha, "vence", "vencem")} amanhã`);
  if (c.contatosHoje) parts.push(`${n(c.contatosHoje, "contato combinado", "contatos combinados")} para hoje`);
  const bills = [];
  if (c.boletosHoje) bills.push(`${n(c.boletosHoje, "boleto vence", "boletos vencem")} hoje`);
  if (c.boletosAtraso) bills.push(`${n(c.boletosAtraso, "boleto atrasado", "boletos atrasados")}`);
  if (c.boletosAmanha) bills.push(`${n(c.boletosAmanha, "boleto vence", "boletos vencem")} amanhã`);
  if (c.boletosTresDias) bills.push(`${n(c.boletosTresDias, "boleto vence", "boletos vencem")} em 3 dias`);
  parts.push(...bills);
  if (!parts.length) return null;
  const hasUrgent = c.cobrancasHoje || c.cobrancasAtraso || c.boletosHoje || c.boletosAtraso || c.contatosHoje;
  return {
    title: hasUrgent ? "Hoje tem o que cobrar" : "Atenção para amanhã",
    body: `${parts.join(" · ")}. Toque para abrir.`,
  };
}

async function loadOpenItems(store, now) {
  const today = startOfDayBrt(now);
  const stamp = (ms) => admin.firestore.Timestamp.fromMillis(ms);
  const [debts, bills, followUps] = await Promise.all([
    store.collection("Debts").where("status_pago", "==", false)
      .where("data_vencimento", "<", stamp(today + 2 * DAY_MS)).get(),
    store.collection("Bills").where("pago", "==", false)
      .where("data_vencimento", "<", stamp(today + 4 * DAY_MS)).get(),
    store.collection("CollectionFollowUps")
      .where("next_contact_at", ">=", stamp(today))
      .where("next_contact_at", "<", stamp(today + DAY_MS)).get(),
  ]);

  const perUser = new Map();
  const of = (uid) => {
    if (!perUser.has(uid)) perUser.set(uid, emptyCounts());
    return perUser.get(uid);
  };
  const bucket = (due) => Math.floor((due - today) / DAY_MS); // <0 atraso, 0 hoje, 1 amanhã, 3 em 3 dias

  for (const doc of debts.docs) {
    const data = doc.data();
    const due = toMillis(data.data_vencimento);
    if (!data.user_id || due == null) continue;
    const day = bucket(due);
    const counts = of(data.user_id);
    if (day < 0) counts.cobrancasAtraso += 1;
    else if (day === 0) counts.cobrancasHoje += 1;
    else if (day === 1) counts.cobrancasAmanha += 1;
  }
  for (const doc of bills.docs) {
    const data = doc.data();
    const due = toMillis(data.data_vencimento);
    if (!data.user_id || due == null) continue;
    const day = bucket(due);
    const counts = of(data.user_id);
    if (day < 0) counts.boletosAtraso += 1;
    else if (day === 0) counts.boletosHoje += 1;
    else if (day === 1) counts.boletosAmanha += 1;
    else if (day === 3) counts.boletosTresDias += 1;
  }
  for (const doc of followUps.docs) {
    const data = doc.data();
    if (data.user_id) of(data.user_id).contatosHoje += 1;
  }
  return perUser;
}

const chunk = (list, size) => {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
};

/**
 * Envia o resumo das 9h. `deps` existe para teste; em produção usa o Firebase Admin.
 * Idempotente por usuário e dia: uma nova execução do agendador não repete o aviso.
 */
async function runDailyReminders(deps = {}) {
  const store = deps.db || db();
  const messaging = deps.messaging || admin.messaging();
  const now = deps.now ?? Date.now();
  const day = dayId(now);
  const stats = { usuarios: 0, enviados: 0, semAparelho: 0, falhas: 0, tokensRemovidos: 0 };

  const perUser = await loadOpenItems(store, now);
  const uids = [...perUser.keys()];

  for (const group of chunk(uids, IN_LIMIT)) {
    const [profiles, devices] = await Promise.all([
      Promise.all(group.map((uid) => store.collection("Users").doc(uid).get())),
      store.collection("Devices").where("uid", "in", group).get(),
    ]);
    const tokensByUser = new Map();
    for (const doc of devices.docs) {
      const data = doc.data();
      if (!tokensByUser.has(data.uid)) tokensByUser.set(data.uid, []);
      tokensByUser.get(data.uid).push({ token: data.token, ref: doc.ref });
    }

    const jobs = [];
    group.forEach((uid, index) => {
      const profileDoc = profiles[index];
      if (!profileDoc.exists) return;
      const profile = profileDoc.data() || {};
      const raw = perUser.get(uid);
      const counts = emptyCounts();
      if (profile.notificacoes_diarias !== false) {
        counts.cobrancasHoje = raw.cobrancasHoje;
        counts.cobrancasAmanha = raw.cobrancasAmanha;
        counts.cobrancasAtraso = raw.cobrancasAtraso;
        if (hasPremium(profile, now)) {
          counts.boletosHoje = raw.boletosHoje;
          counts.boletosAmanha = raw.boletosAmanha;
          counts.boletosAtraso = raw.boletosAtraso;
          counts.boletosTresDias = raw.boletosTresDias;
        }
      }
      if (profile.lembretes_acompanhamento === true) counts.contatosHoje = raw.contatosHoje;
      const message = buildReminder(counts);
      if (!message) return;
      stats.usuarios += 1;
      const devicesOfUser = tokensByUser.get(uid) || [];
      if (!devicesOfUser.length) {
        stats.semAparelho += 1;
        return;
      }
      jobs.push({ uid, message, devices: devicesOfUser });
    });

    for (const job of jobs) {
      const marker = store.collection("RemindersSent").doc(`${job.uid}_${day}`);
      try {
        await marker.create({ uid: job.uid, dia: day, em: admin.firestore.FieldValue.serverTimestamp() });
      } catch (_) {
        continue; // já enviado hoje
      }
      let delivered = 0;
      for (const batch of chunk(job.devices, SEND_LIMIT)) {
        const messages = batch.map(({ token }) => ({
          token,
          notification: { title: job.message.title, body: job.message.body },
          data: { tipo: "resumo_diario", dia: day },
          android: { priority: "high", notification: { channelId: "cobrancas" } },
          apns: { payload: { aps: { sound: "default" } } },
        }));
        const result = await messaging.sendEach(messages);
        for (let i = 0; i < result.responses.length; i += 1) {
          const response = result.responses[i];
          if (response.success) {
            delivered += 1;
          } else if (BAD_TOKEN_CODES.has(response.error?.code)) {
            await batch[i].ref.delete();
            stats.tokensRemovidos += 1;
          } else {
            stats.falhas += 1;
          }
        }
      }
      if (delivered === 0) await marker.delete(); // permite nova tentativa
      stats.enviados += delivered;
    }
  }
  return stats;
}

function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}

/** Guarda o token do aparelho do usuário logado. */
async function registerDevice(uid, body, store = db()) {
  const token = String(body.token || "");
  const platform = String(body.platform || "").toLowerCase();
  if (token.length < 20 || token.length > 4096) throw httpError(400, "Token inválido.");
  if (!["android", "ios"].includes(platform)) throw httpError(400, "Plataforma inválida.");
  const deleted = await store.collection("DeletedAccounts").doc(uid).get();
  if (deleted.exists) throw httpError(403, "Conta excluída.");
  const id = crypto.createHash("sha256").update(token).digest("hex");
  const ref = store.collection("Devices").doc(id);
  const existing = await ref.get();
  await ref.set({
    uid,
    token,
    platform,
    ...(existing.exists ? {} : { criadoEm: admin.firestore.FieldValue.serverTimestamp() }),
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return { ok: true };
}

async function unregisterDevice(uid, body, store = db()) {
  const token = String(body.token || "");
  if (!token) throw httpError(400, "Token inválido.");
  const id = crypto.createHash("sha256").update(token).digest("hex");
  const ref = store.collection("Devices").doc(id);
  const snap = await ref.get();
  if (snap.exists && snap.data().uid === uid) await ref.delete();
  return { ok: true };
}

module.exports = {
  runDailyReminders,
  registerDevice,
  unregisterDevice,
  _test: { buildReminder, startOfDayBrt, dayId, emptyCounts },
};
