const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");

const totp = require("./totp");
const { sendEmail, emailEnabled, escapeHtml } = require("./alerts");

const adminEmailsParam = defineString("ADMIN_EMAILS", { default: "" });

const REGION = "southamerica-east1";
const TIME_ZONE = "America/Sao_Paulo";
const PREMIUM_VALUE = 39.9;
const PLAY_FEE = 0.15;
const ONLINE_MS = 5 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_PREMIUM_DAYS = 366;
const SESSION_MS = 12 * 60 * 60 * 1000;
const MAX_2FA_FAILURES = 5;
const LOCK_MS = 15 * 60 * 1000;
const MAX_NOTE = 2000;
const OWNED_COLLECTIONS = [
  ["Debts", "user_id"],
  ["Payments", "user_id"],
  ["Bills", "user_id"],
  ["PremiumCharges", "userId"],
  ["AdminNotes", "uid"],
];
const OPEN_2FA_ROUTES = new Set(["/2fa/status", "/2fa/verify"]);

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

const db = () => admin.firestore();
const now = () => Date.now();

exports.adminApi = onRequest(
  { region: REGION, cors: true, invoker: "public", timeoutSeconds: 120, memory: "512MiB" },
  async (req, res) => {
    try {
      const caller = await requireAdmin(req);
      const route = String(req.path || "/").replace(/\/+$/, "") || "/";
      const security = await securityOf(caller.uid);
      if (security.ativo && !OPEN_2FA_ROUTES.has(route)) {
        if (!totp.checkSession(security.secret, caller.uid, req.get("x-admin-2fa"))) {
          res.status(401).json({ message: "Digite o código do autenticador.", precisa2fa: true });
          return;
        }
      }

      if (req.method === "GET") {
        const handler = {
          "/overview": () => overview(),
          "/user": () => userFile(String(req.query.uid || "").trim()),
          "/log": () => actionLog(),
          "/2fa/status": () => ({ ativo: security.ativo }),
        }[route];
        if (!handler) throw httpError(404, "Rota não encontrada.");
        res.status(200).json(await handler());
        return;
      }
      if (req.method !== "POST") throw httpError(405, "Rota não encontrada.");

      const body = req.body || {};
      if (route.startsWith("/2fa/")) {
        res.status(200).json(await twoFactor(route, caller, security, body));
        return;
      }

      const uid = String(body.uid || "").trim();
      if (!uid) throw httpError(400, "Informe a pessoa.");
      const target = await targetOf(uid);

      if (route === "/premium") {
        const days = Number(body.days || 30);
        if (!Number.isInteger(days) || days < 1 || days > MAX_PREMIUM_DAYS) {
          throw httpError(400, "Dias inválidos (1 a 366).");
        }
        const result = await givePremium(uid, days);
        await logAction(caller, "premium", target, `+${days} dias, até ${formatDate(result.premiumAte)}`);
        res.status(200).json(result);
        return;
      }
      if (route === "/revoke") {
        await revokePremium(uid);
        await logAction(caller, "tirar_premium", target, "");
        res.status(200).json({ ok: true });
        return;
      }
      if (route === "/delete") {
        if (uid === caller.uid) throw httpError(400, "Você não pode excluir a sua própria conta aqui.");
        const result = await deleteAccount(uid);
        await logAction(caller, "excluir", target, `${result.documentos} documentos apagados`);
        res.status(200).json(result);
        return;
      }
      if (route === "/note") {
        const text = String(body.text || "").trim().slice(0, MAX_NOTE);
        if (!text) throw httpError(400, "Escreva a anotação.");
        const ref = await db().collection("AdminNotes").add({
          uid,
          texto: text,
          por: caller.email || "",
          em: admin.firestore.FieldValue.serverTimestamp(),
        });
        await logAction(caller, "anotacao", target, text.slice(0, 80));
        res.status(200).json({ ok: true, id: ref.id });
        return;
      }
      if (route === "/note/delete") {
        const ref = db().collection("AdminNotes").doc(String(body.id || "x"));
        const snap = await ref.get();
        if (!snap.exists || snap.data().uid !== uid) throw httpError(404, "Anotação não encontrada.");
        await ref.delete();
        res.status(200).json({ ok: true });
        return;
      }
      if (route === "/contacted") {
        const ref = db().collection("AdminContacts").doc(uid);
        if (body.value === false) {
          await ref.delete();
        } else {
          await ref.set({ em: admin.firestore.FieldValue.serverTimestamp(), por: caller.email || "", motivo: String(body.motivo || "").slice(0, 40) });
          await logAction(caller, "chamado", target, String(body.motivo || ""));
        }
        res.status(200).json({ ok: true });
        return;
      }
      throw httpError(404, "Rota não encontrada.");
    } catch (error) {
      if (!error.status) console.error("adminApi", error);
      res.status(error.status || 500).json({ message: error.status ? error.message : "Erro no painel." });
    }
  },
);

exports.adminDailyDigest = onSchedule(
  { schedule: "0 8 * * *", timeZone: TIME_ZONE, region: REGION, timeoutSeconds: 300, memory: "512MiB" },
  async () => {
    const data = await overview();
    if (!emailEnabled()) return;
    const today = startOfDay(now());
    const yesterday = today - DAY_MS;
    const people = data.users.filter((user) => !user.admin);
    const signups = people.filter((user) => user.criadoEm >= yesterday && user.criadoEm < today);
    const events = data.receita.eventos.filter((item) => item.em >= yesterday && item.em < today && !item.teste);
    const charges = events.filter((item) => item.cobranca);
    const lost = events.filter((item) => ["CANCELADA", "SUSPENSA", "EXPIRADA", "ESTORNADA"].includes(item.tipo));
    const segments = attentionCounts(people, now());
    const s = data.stats;

    const lines = [
      `<b>Ontem (${formatDate(yesterday)})</b>`,
      `Cadastros: <b>${signups.length}</b>${signups.length ? ` (${signups.slice(0, 8).map((user) => escapeHtml(user.nome || user.email)).join(", ")}${signups.length > 8 ? "..." : ""})` : ""}`,
      `Cobranças da Play: <b>${charges.length}</b> · ${money(charges.reduce((sum, item) => sum + item.valor, 0))}`,
      lost.length ? `Perdas: <b>${lost.length}</b> (${lost.map((item) => `${escapeHtml(item.nome || "?")} ${item.tipo.toLowerCase()}`).join(", ")})` : "Perdas: nenhuma",
      `<b>Hoje</b>`,
      `Usuários: ${s.total} · ativos em 7 dias: ${s.ativos7d} · Premium: ${s.premium} (${s.premiumPagantes} pagantes)`,
      `Receita do mês até agora: <b>${money(data.receita.mesAtual.bruto)}</b> bruto · ${money(data.receita.mesAtual.liquido)} líquido`,
      `<b>Precisa de atenção</b>`,
      `Premium sumido: ${segments.risco} · Prontos para Premium: ${segments.prontos} · Travou no começo: ${segments.travados}`,
    ];
    await sendEmail(`Pagô: resumo de ${formatDate(yesterday)}`, lines);
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
  if (!email || !adminEmails().includes(email)) {
    throw httpError(403, "Esta conta não é administradora.");
  }
  return token;
}

async function securityOf(uid) {
  const snap = await db().collection("AdminSecurity").doc(uid).get();
  const data = snap.data() || {};
  return { ref: snap.ref, ativo: data.ativo === true && !!data.secret, ...data };
}

async function twoFactor(route, caller, security, body) {
  const code = String(body.code || "");
  if (route === "/2fa/setup") {
    const secret = totp.newSecret();
    await security.ref.set({ pendente: secret }, { merge: true });
    return { secret, uri: totp.otpauthUri(secret, caller.email || "admin") };
  }
  if (route === "/2fa/enable") {
    if (!security.pendente) throw httpError(400, "Gere o código QR de novo.");
    if (!totp.verifyCode(security.pendente, code)) throw httpError(400, "Código errado. Confira a hora do celular e tente de novo.");
    await security.ref.set({ secret: security.pendente, pendente: null, ativo: true, ativadoEm: admin.firestore.FieldValue.serverTimestamp(), falhas: 0 });
    await logAction(caller, "2fa_ativado", null, "");
    return { ok: true, sessao: totp.signSession(security.pendente, caller.uid, SESSION_MS) };
  }
  if (route === "/2fa/verify") {
    if (!security.ativo) throw httpError(400, "O segundo fator não está ligado.");
    const lockedUntil = toMillis(security.bloqueadoAte);
    if (lockedUntil && lockedUntil > now()) {
      throw httpError(429, `Muitas tentativas. Tente de novo às ${formatTime(lockedUntil)}.`);
    }
    if (!totp.verifyCode(security.secret, code)) {
      const failures = (security.falhas || 0) + 1;
      await security.ref.set(
        failures >= MAX_2FA_FAILURES
          ? { falhas: 0, bloqueadoAte: admin.firestore.Timestamp.fromMillis(now() + LOCK_MS) }
          : { falhas: failures },
        { merge: true },
      );
      throw httpError(400, "Código errado.");
    }
    await security.ref.set({ falhas: 0, bloqueadoAte: null }, { merge: true });
    return { sessao: totp.signSession(security.secret, caller.uid, SESSION_MS) };
  }
  if (route === "/2fa/disable") {
    if (!security.ativo) return { ok: true };
    if (!totp.verifyCode(security.secret, code)) throw httpError(400, "Código errado.");
    await security.ref.delete();
    await logAction(caller, "2fa_desligado", null, "");
    return { ok: true };
  }
  throw httpError(404, "Rota não encontrada.");
}

async function overview() {
  const [authUsers, profiles, presence, contacts] = await Promise.all([
    listAuthUsers(),
    db().collection("Users").get(),
    db().collection("Presence").get(),
    db().collection("AdminContacts").get(),
  ]);

  const profileById = new Map(profiles.docs.map((doc) => [doc.id, doc.data()]));
  const seenById = new Map(presence.docs.map((doc) => [doc.id, doc.data()]));
  const contactById = new Map(contacts.docs.map((doc) => [doc.id, doc.data()]));
  const at = now();
  const allowed = adminEmails();

  const users = authUsers.map((record) => {
    const profile = profileById.get(record.uid) || {};
    const seen = seenById.get(record.uid) || {};
    const contact = contactById.get(record.uid);
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
      premiumAtivo: profile.is_premium === true && !!premiumUntil && premiumUntil > at,
      premiumOrigem: premiumOrigin(profile.premium_transaction_id),
      admin: allowed.includes(String(record.email || "").toLowerCase()),
      desativado: record.disabled === true,
      chamadoEm: contact ? toMillis(contact.em) : null,
    };
  });

  await attachCounts(users);
  users.sort((a, b) => (b.ultimoAcesso || 0) - (a.ultimoAcesso || 0));

  const people = users.filter((user) => !user.admin);
  const premium = people.filter((user) => user.premiumAtivo);
  const paying = premium.filter((user) => user.premiumOrigem !== "admin");
  const activeSince = (ms) => people.filter((user) => user.ultimoAcesso && at - user.ultimoAcesso <= ms).length;

  const signups = [];
  for (let i = 13; i >= 0; i -= 1) {
    const start = startOfDay(at - i * DAY_MS);
    const end = start + DAY_MS;
    signups.push({
      dia: start,
      total: people.filter((user) => user.criadoEm && user.criadoEm >= start && user.criadoEm < end).length,
    });
  }

  const stats = {
    total: people.length,
    novos7d: people.filter((user) => user.criadoEm && at - user.criadoEm <= 7 * DAY_MS).length,
    online: activeSince(ONLINE_MS),
    ativos24h: activeSince(DAY_MS),
    ativos7d: activeSince(7 * DAY_MS),
    ativos30d: activeSince(30 * DAY_MS),
    premium: premium.length,
    premiumPagantes: paying.length,
    premiumCortesia: premium.length - paying.length,
    premiumVence7d: premium.filter((user) => user.premiumAte - at <= 7 * DAY_MS).length,
    receitaEstimada: Math.round(paying.length * PREMIUM_VALUE * 100) / 100,
    cadastros14d: signups,
  };

  const nameById = new Map(users.map((user) => [user.uid, user.nome || user.email]));
  const [receita, historico] = await Promise.all([revenue(at, nameById), saveSnapshot(at, stats)]);

  return { geradoEm: at, stats, receita, historico, emailLigado: emailEnabled(), users };
}

async function revenue(at, nameById) {
  const monthStart = startOfMonth(at);
  const previousStart = startOfMonth(monthStart - DAY_MS);
  const snap = await db()
    .collection("PlayEvents")
    .where("em", ">=", admin.firestore.Timestamp.fromMillis(previousStart))
    .get();
  const eventos = snap.docs
    .map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        uid: data.uid || "",
        nome: nameById.get(data.uid) || "",
        tipo: data.tipo,
        cobranca: data.cobranca === true,
        valor: Number(data.valor || 0),
        teste: data.teste === true,
        em: toMillis(data.em) || 0,
      };
    })
    .sort((a, b) => b.em - a.em);

  const period = (from, to) => {
    const list = eventos.filter((item) => !item.teste && item.em >= from && item.em < to);
    const charges = list.filter((item) => item.cobranca);
    const bruto = round2(charges.reduce((sum, item) => sum + item.valor, 0));
    return {
      bruto,
      liquido: round2(bruto * (1 - PLAY_FEE)),
      cobrancas: charges.length,
      novas: list.filter((item) => item.tipo === "COMPRA").length,
      renovacoes: list.filter((item) => item.tipo === "RENOVADA" || item.tipo === "RECUPERADA").length,
      cancelamentos: list.filter((item) => item.tipo === "CANCELADA").length,
      falhas: list.filter((item) => ["SUSPENSA", "PERIODO_DE_CARENCIA"].includes(item.tipo)).length,
    };
  };

  return {
    taxaPlay: PLAY_FEE,
    mesAtual: period(monthStart, Number.MAX_SAFE_INTEGER),
    mesAnterior: period(previousStart, monthStart),
    eventos: eventos.slice(0, 40),
  };
}

async function saveSnapshot(at, stats) {
  const id = dayId(at);
  const collection = db().collection("AdminStats");
  await collection.doc(id).set(
    {
      dia: id,
      total: stats.total,
      ativos7d: stats.ativos7d,
      ativos30d: stats.ativos30d,
      premium: stats.premium,
      premiumPagantes: stats.premiumPagantes,
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  const snap = await collection.where("dia", ">=", dayId(at - 70 * DAY_MS)).get();
  return snap.docs
    .map((doc) => {
      const data = doc.data();
      return {
        dia: data.dia,
        total: data.total,
        ativos7d: data.ativos7d,
        ativos30d: data.ativos30d,
        premium: data.premium,
        premiumPagantes: data.premiumPagantes,
      };
    })
    .sort((a, b) => a.dia.localeCompare(b.dia));
}

async function userFile(uid) {
  if (!uid) throw httpError(400, "Informe a pessoa.");
  const record = await admin.auth().getUser(uid).catch(() => null);
  if (!record) throw httpError(404, "Pessoa não encontrada.");
  const [profile, presence, debts, payments, bills, subs, events, notes, log, contact] = await Promise.all([
    db().collection("Users").doc(uid).get(),
    db().collection("Presence").doc(uid).get(),
    db().collection("Debts").where("user_id", "==", uid).select("created_at", "status_pago").get(),
    db().collection("Payments").where("user_id", "==", uid).count().get(),
    db().collection("Bills").where("user_id", "==", uid).select("pago").get(),
    db().collection("PlaySubscriptions").where("uid", "==", uid).get(),
    db().collection("PlayEvents").where("uid", "==", uid).get(),
    db().collection("AdminNotes").where("uid", "==", uid).get(),
    db().collection("AdminLog").where("uid", "==", uid).get(),
    db().collection("AdminContacts").doc(uid).get(),
  ]);

  const at = now();
  const months = [];
  for (let i = 5; i >= 0; i -= 1) {
    const start = startOfMonth(addMonths(at, -i));
    months.push({ mes: start, fim: startOfMonth(addMonths(at, -i + 1)), total: 0 });
  }
  let open = 0;
  for (const doc of debts.docs) {
    const data = doc.data();
    if (data.status_pago !== true) open += 1;
    const created = toMillis(data.created_at);
    const bucket = months.find((month) => created && created >= month.mes && created < month.fim);
    if (bucket) bucket.total += 1;
  }

  const p = profile.data() || {};
  const historico = [
    ...events.docs.map((doc) => {
      const data = doc.data();
      return { em: toMillis(data.em), origem: "play", tipo: data.tipo, detalhe: data.cobranca ? money(data.valor) : "", teste: data.teste === true };
    }),
    ...log.docs.map((doc) => {
      const data = doc.data();
      return { em: toMillis(data.em), origem: "admin", tipo: data.acao, detalhe: data.detalhe || "", por: data.por || "" };
    }),
  ].sort((a, b) => (b.em || 0) - (a.em || 0));

  return {
    uid,
    nome: p.nome || record.displayName || "",
    email: record.email || "",
    telefone: p.telefone || "",
    criadoEm: Date.parse(record.metadata.creationTime || "") || null,
    ultimoLogin: Date.parse(record.metadata.lastSignInTime || "") || null,
    ultimoAcesso: toMillis(presence.data()?.last_seen_at),
    plataforma: presence.data()?.plataforma || "",
    premiumAtivo: p.is_premium === true && toMillis(p.premium_vence_em) > at,
    premiumAte: toMillis(p.premium_vence_em),
    premiumOrigem: premiumOrigin(p.premium_transaction_id),
    configurou: {
      chavePix: !!p.chave_pix,
      banco: !!p.banco,
      mensagemPropria: !!p.mensagem_cobranca,
      lembretes: p.notificacoes_diarias !== false,
      biometria: p.acesso_biometrico === true,
    },
    uso: {
      lancamentos: debts.size,
      emAberto: open,
      pagamentos: payments.data().count,
      boletos: bills.size,
      boletosEmAberto: bills.docs.filter((doc) => doc.data().pago !== true).length,
      porMes: months.map(({ mes, total }) => ({ mes, total })),
    },
    assinaturas: subs.docs.map((doc) => {
      const data = doc.data();
      return {
        estado: data.estado || "",
        verificada: data.verificada === true,
        venceEm: toMillis(data.venceEm),
        renovaSozinha: data.renovaSozinha === true,
        valor: data.valor || null,
        teste: data.teste === true,
      };
    }),
    historico,
    anotacoes: notes.docs
      .map((doc) => ({ id: doc.id, texto: doc.data().texto, por: doc.data().por, em: toMillis(doc.data().em) }))
      .sort((a, b) => (b.em || 0) - (a.em || 0)),
    chamadoEm: contact.exists ? toMillis(contact.data().em) : null,
  };
}

async function actionLog() {
  const snap = await db().collection("AdminLog").orderBy("em", "desc").limit(150).get();
  return {
    itens: snap.docs.map((doc) => {
      const data = doc.data();
      return { em: toMillis(data.em), por: data.por, acao: data.acao, uid: data.uid, alvo: data.alvo, detalhe: data.detalhe };
    }),
  };
}

async function logAction(caller, action, target, detail) {
  await db().collection("AdminLog").add({
    em: admin.firestore.FieldValue.serverTimestamp(),
    por: caller.email || caller.uid,
    acao: action,
    uid: target?.uid || null,
    alvo: target?.label || "",
    detalhe: String(detail || "").slice(0, 200),
  });
}

async function targetOf(uid) {
  const [record, profile] = await Promise.all([
    admin.auth().getUser(uid).catch(() => null),
    db().collection("Users").doc(uid).get(),
  ]);
  const name = profile.data()?.nome || record?.displayName || "";
  const email = record?.email || "";
  return { uid, label: [name, email].filter(Boolean).join(" · ") || uid };
}

function attentionCounts(people, at) {
  const idle = (user) => at - (user.ultimoAcesso || user.criadoEm || 0);
  const pending = (user) => !user.chamadoEm || at - user.chamadoEm > 7 * DAY_MS;
  const list = people.filter((user) => !user.desativado && pending(user));
  return {
    risco: list.filter((user) => user.premiumAtivo && idle(user) >= 7 * DAY_MS).length,
    prontos: list.filter(
      (user) =>
        !user.premiumAtivo &&
        (((user.uso?.lancamentos || 0) >= 10 && idle(user) <= 7 * DAY_MS) ||
          (user.premiumAte && user.premiumAte <= at && at - user.premiumAte <= 30 * DAY_MS)),
    ).length,
    travados: list.filter(
      (user) => user.uso?.lancamentos === 0 && user.criadoEm && at - user.criadoEm >= DAY_MS && at - user.criadoEm <= 30 * DAY_MS,
    ).length,
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
  const countOf = async (collection, uid) => {
    const snap = await db().collection(collection).where("user_id", "==", uid).count().get();
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
  const ref = db().collection("Users").doc(uid);
  const snap = await ref.get();
  const current = toMillis(snap.data()?.premium_vence_em);
  const active = snap.data()?.is_premium === true && current && current > now();
  const base = active ? current : now();
  const until = new Date(base + days * DAY_MS);
  await ref.set(
    {
      is_premium: true,
      premium_vence_em: admin.firestore.Timestamp.fromDate(until),
      premium_transaction_id: `admin_${days}d_${now()}`,
    },
    { merge: true },
  );
  return { ok: true, premiumAte: until.getTime() };
}

async function revokePremium(uid) {
  await db().collection("Users").doc(uid).set(
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

  let removed = 0;
  for (const [collection, field] of OWNED_COLLECTIONS) {
    removed += await deleteWhere(db().collection(collection).where(field, "==", uid));
  }
  await db().collection("Users").doc(uid).delete();
  await db().collection("Presence").doc(uid).delete();
  await db().collection("AdminContacts").doc(uid).delete();
  if (record) await admin.auth().deleteUser(uid);
  return { ok: true, documentos: removed };
}

async function deleteOwnAccount(user) {
  const target = await targetOf(user.uid);
  const result = await deleteAccount(user.uid);
  await logAction(user, "excluiu_a_propria_conta", target, `${result.documentos} documentos apagados`);
  return result;
}

async function deleteWhere(query) {
  let total = 0;
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return total;
    const batch = db().batch();
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

const SP_OFFSET = 3 * 60 * 60 * 1000;

function startOfDay(ms) {
  const local = new Date(ms - SP_OFFSET);
  local.setUTCHours(0, 0, 0, 0);
  return local.getTime() + SP_OFFSET;
}

function startOfMonth(ms) {
  const local = new Date(ms - SP_OFFSET);
  return Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1) + SP_OFFSET;
}

function addMonths(ms, months) {
  const local = new Date(ms - SP_OFFSET);
  return Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + months, 15) + SP_OFFSET;
}

function dayId(ms) {
  return new Date(ms - SP_OFFSET).toISOString().slice(0, 10);
}

function formatDate(ms) {
  return new Date(ms).toLocaleDateString("pt-BR", { timeZone: TIME_ZONE });
}

function formatTime(ms) {
  return new Date(ms).toLocaleTimeString("pt-BR", { timeZone: TIME_ZONE, hour: "2-digit", minute: "2-digit" });
}

function money(value) {
  return `R$ ${Number(value || 0).toFixed(2).replace(".", ",")}`;
}

function round2(value) {
  return Math.round(value * 100) / 100;
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

module.exports = { adminApi: exports.adminApi, adminDailyDigest: exports.adminDailyDigest, deleteOwnAccount, _test: { attentionCounts, startOfMonth, dayId } };
