import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  updatePassword,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";

const firebaseConfig = {
  apiKey: "AIzaSyCy2sI-4oJ4Zqfy85a_vN8hG_hS4ire6d8",
  authDomain: "tapago-ae948.firebaseapp.com",
  projectId: "tapago-ae948",
  appId: "1:1077428127080:web:e82621d06da4bf5c0042dd",
  messagingSenderId: "1077428127080",
};

const API = "https://southamerica-east1-tapago-ae948.cloudfunctions.net/adminApi";
const DAY = 24 * 60 * 60 * 1000;
const ONLINE_MS = 5 * 60 * 1000;
const AUTO_REFRESH_MS = 60 * 1000;
const SIGNATURE = "Kevison";
const CONTACT_COOLDOWN = 7 * DAY;
const SESSION_KEY = "pago_admin_2fa";

const EVENT_LABELS = {
  COMPRA: "assinou o Premium",
  RENOVADA: "renovou o Premium",
  RECUPERADA: "voltou a pagar (pagamento recuperado)",
  CANCELADA: "cancelou a renovação",
  SUSPENSA: "teve o pagamento recusado",
  PERIODO_DE_CARENCIA: "está em carência (pagamento recusado)",
  REATIVADA: "reativou a assinatura",
  ESTORNADA: "teve a compra estornada",
  EXPIRADA: "perdeu o Premium (expirou)",
  PAUSADA: "pausou a assinatura",
};

const ACTION_LABELS = {
  premium: "deu Premium",
  tirar_premium: "tirou o Premium",
  excluir: "excluiu a conta",
  anotacao: "anotou",
  chamado: "marcou como chamado",
  "2fa_ativado": "ligou o segundo fator",
  "2fa_desligado": "desligou o segundo fator",
};

const SEGMENTS = {
  risco: {
    label: "Premium sumido",
    why: "Têm Premium ativo e não abrem o app há 7 dias ou mais. São os que mais podem cancelar.",
    test: (user, now) => user.premiumAtivo && idleFor(user, now) >= 7 * DAY,
    reason: (user, now) =>
      `Premium${originLabel(user) ? ` ${originLabel(user)}` : ""} até ${dateFmt.format(user.premiumAte)} · sem abrir há ${daysText(idleFor(user, now))}`,
    message: (name) =>
      `Oi ${name}, aqui é o ${SIGNATURE}, do Pagô! Vi que faz uns dias que você não abre o app. Ficou alguma dúvida ou travou em alguma coisa? Posso te ajudar por aqui.`,
    sort: (a, b, now) => idleFor(b, now) - idleFor(a, now),
  },
  prontos: {
    label: "Prontos para Premium",
    why: "Grátis e usando: abriram o app nos últimos 7 dias com 10 ou mais lançamentos, ou o Premium venceu há menos de 30 dias.",
    test: (user, now) => !user.premiumAtivo && (heavyFree(user, now) || recentlyExpired(user, now)),
    reason: (user, now) =>
      recentlyExpired(user, now)
        ? `Premium venceu ${dateFmt.format(user.premiumAte)} e não renovou`
        : `${user.uso.lancamentos} lançamentos · último acesso ${relative(user.ultimoAcesso)}`,
    message: (name, user, now) =>
      recentlyExpired(user, now)
        ? `Oi ${name}, aqui é o ${SIGNATURE}, do Pagô! Seu Premium venceu. Sentiu falta de lançar por voz, ler recibo pela câmera ou dos boletos a pagar? Se quiser voltar, é só tocar em Premium no menu do app. Qualquer dúvida, me chama.`
        : `Oi ${name}, aqui é o ${SIGNATURE}, do Pagô! Vi que você já tem ${user.uso.lancamentos} lançamentos na caderneta, muito bom! No Premium dá para lançar falando, ler recibo pela câmera e controlar seus boletos a pagar. Quer testar 7 dias de graça? É só me responder.`,
    sort: (a, b) => (b.uso?.lancamentos || 0) - (a.uso?.lancamentos || 0),
    trial: true,
  },
  travados: {
    label: "Travou no começo",
    why: "Criaram a conta há 1 a 30 dias e ainda não fizeram nenhum lançamento.",
    test: (user, now) =>
      user.uso?.lancamentos === 0 &&
      user.criadoEm &&
      now - user.criadoEm >= DAY &&
      now - user.criadoEm <= 30 * DAY,
    reason: (user) => `Cadastro ${relative(user.criadoEm)} · nenhum lançamento`,
    message: (name) =>
      `Oi ${name}, aqui é o ${SIGNATURE}, do Pagô! Vi que você criou sua conta mas ainda não lançou ninguém na caderneta. Quer que eu te mostre como lançar o primeiro fiado? Leva 1 minuto.`,
    sort: (a, b) => (b.criadoEm || 0) - (a.criadoEm || 0),
  },
};

const auth = getAuth(initializeApp(firebaseConfig));
const $ = (id) => document.getElementById(id);
const money = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const dateFmt = new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "2-digit", year: "2-digit" });
const dateTimeFmt = new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
const dayFmt = new Intl.DateTimeFormat("pt-BR", { day: "2-digit" });
const monthFmt = new Intl.DateTimeFormat("pt-BR", { month: "short" });

const state = {
  data: null,
  users: [],
  filter: "all",
  query: "",
  loading: false,
  timer: null,
  focus: null,
  range: "all",
  tab: "geral",
  file: null,
};

onAuthStateChanged(auth, (user) => {
  $("login").hidden = !!user;
  $("app").hidden = !user;
  $("twofa").hidden = true;
  clearInterval(state.timer);
  if (!user) {
    sessionStorage.removeItem(SESSION_KEY);
    return;
  }
  load();
  state.timer = setInterval(() => {
    if (document.visibilityState === "visible" && !$("app").hidden) load({ quiet: true });
  }, AUTO_REFRESH_MS);
});

$("login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = $("login-btn");
  button.disabled = true;
  $("login-error").textContent = "";
  try {
    await signInWithEmailAndPassword(auth, $("email").value.trim(), $("password").value);
  } catch (_) {
    $("login-error").textContent = "E-mail ou senha incorretos.";
  } finally {
    button.disabled = false;
  }
});

$("twofa-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = $("twofa-btn");
  button.disabled = true;
  $("twofa-error").textContent = "";
  try {
    const data = await api("/2fa/verify", { code: $("twofa-code").value });
    sessionStorage.setItem(SESSION_KEY, data.sessao);
    $("twofa-code").value = "";
    $("twofa").hidden = true;
    $("app").hidden = false;
    await load();
  } catch (error) {
    $("twofa-error").textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

$("twofa-logout").addEventListener("click", () => signOut(auth));
$("logout").addEventListener("click", () => signOut(auth));
$("refresh").addEventListener("click", () => load());
$("export").addEventListener("click", exportCsv);
$("security-btn").addEventListener("click", openSecurity);

$("password-btn").addEventListener("click", async () => {
  const next = prompt("Nova senha (mínimo 10 caracteres):");
  if (next == null) return;
  if (next.length < 10) {
    toast("A senha precisa de pelo menos 10 caracteres.");
    return;
  }
  if (prompt("Repita a nova senha:") !== next) {
    toast("As senhas não conferem.");
    return;
  }
  try {
    await updatePassword(auth.currentUser, next);
    toast("Senha trocada.");
  } catch (error) {
    toast(
      error.code === "auth/requires-recent-login"
        ? "Por segurança, saia, entre de novo e troque a senha logo em seguida."
        : "Não foi possível trocar a senha.",
    );
  }
});

$("tabs").addEventListener("click", (event) => {
  const tab = event.target.closest("[data-tab]");
  if (!tab) return;
  state.tab = tab.dataset.tab;
  document.querySelectorAll(".tab").forEach((item) => item.classList.toggle("active", item === tab));
  document.querySelectorAll("[data-page]").forEach((page) => (page.hidden = page.dataset.page !== state.tab));
  if (state.tab === "registro") loadLog();
});

$("search").addEventListener("input", (event) => {
  state.query = event.target.value.trim().toLowerCase();
  renderUsers();
});

$("filters").addEventListener("click", (event) => {
  const chip = event.target.closest("[data-filter]");
  if (!chip) return;
  state.filter = chip.dataset.filter;
  $("filters").querySelectorAll(".chip").forEach((item) => item.classList.toggle("active", item === chip));
  renderUsers();
});

$("funnel-range").addEventListener("click", (event) => {
  const chip = event.target.closest("[data-range]");
  if (!chip) return;
  state.range = chip.dataset.range;
  $("funnel-range").querySelectorAll(".chip").forEach((item) => item.classList.toggle("active", item === chip));
  renderFunnel();
});

document.querySelectorAll(".drawer").forEach((layer) =>
  layer.addEventListener("click", (event) => {
    if (event.target.closest("[data-close]")) closeLayer(layer);
  }),
);

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") document.querySelectorAll(".drawer:not([hidden])").forEach(closeLayer);
});

function closeLayer(layer) {
  layer.hidden = true;
  if (layer.id === "drawer") state.file = null;
}

async function api(path, body, attempt = 1) {
  const token = await auth.currentUser.getIdToken();
  const session = sessionStorage.getItem(SESSION_KEY);
  let response;
  try {
    response = await fetch(`${API}${path}`, {
      method: body ? "POST" : "GET",
      headers: {
        authorization: `Bearer ${token}`,
        ...(session ? { "x-admin-2fa": session } : {}),
        ...(body ? { "content-type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (_) {
    if (attempt < 3) {
      await new Promise((resolve) => setTimeout(resolve, 1500 * attempt));
      return api(path, body, attempt + 1);
    }
    throw new Error("Sem conexão com o servidor. Tente Atualizar.");
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (data.precisa2fa) {
      sessionStorage.removeItem(SESSION_KEY);
      $("app").hidden = true;
      $("twofa").hidden = false;
      $("twofa-code").focus();
    }
    const error = new Error(data.message || "Falha no servidor.");
    error.status = response.status;
    error.twofa = !!data.precisa2fa;
    throw error;
  }
  return data;
}

async function load({ quiet = false } = {}) {
  if (state.loading) return;
  state.loading = true;
  $("refresh").disabled = true;
  if (!quiet && !state.users.length) $("users").innerHTML = `<div class="empty">Carregando...</div>`;
  try {
    const data = await api("/overview");
    state.data = data;
    state.users = data.users || [];
    renderAll();
    $("updated").textContent = `Atualizado ${new Date(data.geradoEm).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}`;
    checkSecurityBanner();
  } catch (error) {
    if (error.twofa) return;
    if (error.status === 403) {
      toast("Esta conta não é administradora.");
      await signOut(auth);
      $("login-error").textContent = "Esta conta não é administradora.";
    } else if (!quiet) {
      $("users").innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
      toast(error.message);
    }
  } finally {
    state.loading = false;
    $("refresh").disabled = false;
  }
}

function renderAll() {
  const data = state.data;
  renderStats(data.stats, data.receita);
  renderFocus();
  renderRevenue(data.receita);
  renderMonthly();
  renderFunnel();
  renderRetention();
  renderChart(data.stats.cadastros14d || []);
  renderFeed();
  renderUsers();
}

let securityChecked = false;
async function checkSecurityBanner() {
  if (securityChecked) return;
  securityChecked = true;
  const notes = [];
  try {
    const status = await api("/2fa/status");
    if (!status.ativo) {
      notes.push(`Ligue o segundo fator para proteger o painel. <button class="link" data-open-security>Ligar agora</button>`);
    }
  } catch (_) {}
  if (state.data && !state.data.emailLigado) {
    notes.push("O resumo diário e os alertas por e-mail estão desligados: falta a chave do Resend no servidor.");
  }
  $("banner").innerHTML = notes.map((note) => `<div class="banner">${note}</div>`).join("");
  $("banner").querySelector("[data-open-security]")?.addEventListener("click", openSecurity);
}

function renderStats(stats, receita) {
  const cards = [
    { label: "Online agora", value: stats.online, hint: "usaram nos últimos 5 min", hero: true, dot: true },
    { label: "Ativos 24h", value: stats.ativos24h, hint: `${stats.ativos7d} em 7 dias · ${stats.ativos30d} em 30` },
    { label: "Cadastros", value: stats.total, hint: `+${stats.novos7d} nos últimos 7 dias` },
    { label: "Premium ativos", value: stats.premium, hint: `${stats.premiumPagantes} pagantes · ${stats.premiumCortesia} cortesia` },
    {
      label: "Receita do mês (Play)",
      value: money.format(receita.mesAtual.bruto),
      hint: receita.mesAtual.cobrancas
        ? `${money.format(receita.mesAtual.liquido)} líquido · ${receita.mesAtual.cobrancas} cobranças`
        : `estimada: ${money.format(stats.receitaEstimada)}/mês`,
    },
    { label: "Premium vence em 7 dias", value: stats.premiumVence7d, hint: "podem não renovar" },
  ];
  $("stats").innerHTML = cards
    .map(
      (card) => `
      <div class="stat${card.hero ? " hero" : ""}">
        <div class="label">${card.dot ? '<span class="dot"></span>' : ""}${card.label}</div>
        <div class="value">${card.value}</div>
        <div class="hint">${card.hint}</div>
      </div>`,
    )
    .join("");
}

function renderRevenue(receita) {
  const now = receita.mesAtual;
  const before = receita.mesAnterior;
  const rows = [
    ["Faturamento bruto", money.format(now.bruto), money.format(before.bruto)],
    [`Líquido (sem os ${Math.round(receita.taxaPlay * 100)}% da Google)`, money.format(now.liquido), money.format(before.liquido)],
    ["Assinaturas novas", now.novas, before.novas],
    ["Renovações", now.renovacoes, before.renovacoes],
    ["Cancelamentos", now.cancelamentos, before.cancelamentos],
    ["Pagamentos recusados", now.falhas, before.falhas],
  ];
  const empty = !receita.eventos.length;
  $("revenue").innerHTML = `
    <table class="table">
      <thead><tr><th></th><th>Este mês</th><th>Mês passado</th></tr></thead>
      <tbody>${rows.map(([label, a, b]) => `<tr><td>${label}</td><td><b>${a}</b></td><td>${b}</td></tr>`).join("")}</tbody>
    </table>
    <p class="muted small">${
      empty
        ? "Ainda sem cobranças registradas. Os números aparecem quando a primeira assinatura for feita pela Play (e as renovações, depois de ligar os avisos da Play)."
        : "Valores conferidos com a Google. Compras de teste ficam de fora. A Google paga o líquido no mês seguinte."
    }</p>`;
}

function renderMonthly() {
  const now = Date.now();
  const people = state.users.filter((user) => !user.admin);
  const monthStart = startOfMonth(now);
  const prevStart = startOfMonth(monthStart - DAY);
  const samePoint = prevStart + (now - monthStart);
  const signupsNow = people.filter((user) => user.criadoEm >= monthStart).length;
  const signupsPrev = people.filter((user) => user.criadoEm >= prevStart && user.criadoEm < Math.min(samePoint, monthStart)).length;

  const history = state.data.historico || [];
  const targetDay = dayId(now - 30 * DAY);
  const past = history.filter((item) => item.dia <= targetDay).pop() || null;
  const stats = state.data.stats;
  const receita = state.data.receita;

  const rows = [
    ["Cadastros (mesmo período)", signupsNow, signupsPrev],
    ["Receita bruta da Play", money.format(receita.mesAtual.bruto), money.format(receita.mesAnterior.bruto), receita.mesAtual.bruto, receita.mesAnterior.bruto],
    ["Premium ativos", stats.premium, past ? past.premium : null],
    ["Pagantes", stats.premiumPagantes, past ? past.premiumPagantes : null],
    ["Ativos em 7 dias", stats.ativos7d, past ? past.ativos7d : null],
    ["Usuários", stats.total, past ? past.total : null],
  ];
  const first = history[0]?.dia;
  $("monthly").innerHTML = `
    <table class="table">
      <thead><tr><th></th><th>Agora</th><th>Há 1 mês</th><th></th></tr></thead>
      <tbody>${rows
        .map(([label, a, b, rawA = a, rawB = b]) => `<tr><td>${label}</td><td><b>${a}</b></td><td>${b ?? "—"}</td><td>${trend(rawA, rawB)}</td></tr>`)
        .join("")}</tbody>
    </table>
    <p class="muted small">${
      past
        ? "Cadastros comparam o mês atual com o mesmo número de dias do mês passado."
        : `O painel guarda uma foto por dia desde ${first ? first.split("-").reverse().join("/") : "hoje"}. A comparação com 1 mês atrás aparece quando completar 30 dias.`
    }</p>`;
}

function trend(current, previous) {
  if (previous == null || typeof current !== "number" || typeof previous !== "number") return "";
  if (current === previous) return `<span class="trend">=</span>`;
  if (!previous) return `<span class="trend up">novo</span>`;
  const pct = Math.round(((current - previous) / previous) * 100);
  return `<span class="trend ${pct >= 0 ? "up" : "down"}">${pct >= 0 ? "▲" : "▼"} ${Math.abs(pct)}%</span>`;
}

function renderFunnel() {
  const now = Date.now();
  let people = state.users.filter((user) => !user.admin && !user.desativado);
  if (state.range === "30") people = people.filter((user) => user.criadoEm && now - user.criadoEm <= 30 * DAY);
  const conditions = [
    ["Criaram a conta", () => true],
    ["Fizeram o 1º lançamento", (user) => (user.uso?.lancamentos || 0) > 0],
    ["Chegaram a 5 lançamentos", (user) => (user.uso?.lancamentos || 0) >= 5],
    ["Continuam usando (abriram nos últimos 7 dias)", (user) => user.ultimoAcesso && now - user.ultimoAcesso <= 7 * DAY],
    ["Assinaram o Premium", (user) => user.premiumAtivo && user.premiumOrigem !== "admin"],
  ];
  const steps = [];
  conditions.reduce((list, [label, test]) => {
    const next = list.filter(test);
    steps.push([label, next]);
    return next;
  }, people);
  const total = Math.max(1, steps[0][1].length);
  $("funnel").innerHTML = steps
    .map(([label, list], index) => {
      const prev = index ? steps[index - 1][1].length : list.length;
      const pct = Math.round((list.length / total) * 100);
      const stepPct = prev ? Math.round((list.length / prev) * 100) : 0;
      return `
        <div class="funnel-row">
          <div class="funnel-label">${label}</div>
          <div class="funnel-bar"><i style="width:${Math.max(2, pct)}%"></i></div>
          <div class="funnel-num"><b>${list.length}</b> <span class="muted small">${pct}%${index && prev ? ` · ${stepPct}% da etapa anterior` : ""}</span></div>
        </div>`;
    })
    .join("");
}

function renderRetention() {
  const now = Date.now();
  const people = state.users.filter((user) => !user.admin && user.criadoEm);
  const weeks = [];
  const thisWeek = startOfWeek(now);
  for (let i = 0; i < 8; i += 1) {
    const start = thisWeek - i * 7 * DAY;
    const end = start + 7 * DAY;
    const cohort = people.filter((user) => user.criadoEm >= start && user.criadoEm < end);
    const rate = (days) => {
      const eligible = cohort.filter((user) => now - user.criadoEm >= days * DAY);
      if (!eligible.length) return null;
      const back = eligible.filter((user) => user.ultimoAcesso && user.ultimoAcesso - user.criadoEm >= days * DAY);
      return { pct: Math.round((back.length / eligible.length) * 100), n: back.length, of: eligible.length };
    };
    weeks.push({ start, size: cohort.length, d7: rate(7), d30: rate(30), lanc: cohort.filter((user) => (user.uso?.lancamentos || 0) > 0).length });
  }
  const cell = (value) =>
    value
      ? `<span class="heat" style="--p:${value.pct}">${value.pct}%</span> <span class="muted small">${value.n}/${value.of}</span>`
      : `<span class="muted">—</span>`;
  $("retention").innerHTML = `
    <table class="table">
      <thead><tr><th>Semana</th><th>Cadastros</th><th>Lançaram</th><th>Voltaram após 7 dias</th><th>Após 30 dias</th></tr></thead>
      <tbody>${weeks
        .map(
          (week) => `<tr><td>${dateFmt.format(week.start)}</td><td>${week.size}</td><td>${week.size ? `${Math.round((week.lanc / week.size) * 100)}%` : "—"}</td><td>${week.size ? cell(week.d7) : "—"}</td><td>${week.size ? cell(week.d30) : "—"}</td></tr>`,
        )
        .join("")}</tbody>
    </table>
    <p class="muted small">"Voltou" = o último acesso foi pelo menos 7 (ou 30) dias depois do cadastro. "—" quando a semana ainda não completou o prazo.</p>`;
}

function renderChart(days) {
  const max = Math.max(1, ...days.map((day) => day.total));
  $("chart").innerHTML = days
    .map(
      (day) => `
      <div class="bar${day.total ? "" : " zero"}" title="${dateFmt.format(day.dia)}: ${day.total}">
        <span>${day.total || ""}</span>
        <i style="height:${Math.max(3, (day.total / max) * 90)}px"></i>
        <span>${dayFmt.format(day.dia)}</span>
      </div>`,
    )
    .join("");
}

function renderFeed() {
  const now = Date.now();
  const signups = state.users
    .filter((user) => !user.admin && user.criadoEm && now - user.criadoEm <= 7 * DAY)
    .map((user) => ({ em: user.criadoEm, uid: user.uid, nome: user.nome || user.email, texto: "criou a conta", tipo: "cadastro" }));
  const play = (state.data.receita.eventos || []).map((item) => ({
    em: item.em,
    uid: item.uid,
    nome: item.nome || "Assinante",
    texto: `${EVENT_LABELS[item.tipo] || item.tipo.toLowerCase()}${item.cobranca ? ` · ${money.format(item.valor)}` : ""}${item.teste ? " · teste" : ""}`,
    tipo: ["CANCELADA", "SUSPENSA", "PERIODO_DE_CARENCIA", "ESTORNADA", "EXPIRADA"].includes(item.tipo) ? "perda" : "play",
  }));
  const items = [...signups, ...play].sort((a, b) => b.em - a.em).slice(0, 25);
  $("feed").innerHTML = items.length
    ? items
        .map(
          (item) => `
        <div class="feed-item ${item.tipo}">
          <span class="feed-dot"></span>
          <div><button class="link" data-file="${escapeHtml(item.uid)}">${escapeHtml(item.nome)}</button> ${escapeHtml(item.texto)}</div>
          <span class="muted small">${relative(item.em)}</span>
        </div>`,
        )
        .join("")
    : `<div class="empty">Nada nos últimos 7 dias.</div>`;
}

$("feed").addEventListener("click", (event) => {
  const link = event.target.closest("[data-file]");
  if (link?.dataset.file) openFile(link.dataset.file);
});

function idleFor(user, now) {
  return now - (user.ultimoAcesso || user.criadoEm || 0);
}

function heavyFree(user, now) {
  return (user.uso?.lancamentos || 0) >= 10 && idleFor(user, now) <= 7 * DAY;
}

function recentlyExpired(user, now) {
  return !!user.premiumAte && user.premiumAte <= now && now - user.premiumAte <= 30 * DAY;
}

function originLabel(user) {
  return { admin: "cortesia", pix: "PIX", play: "Play" }[user.premiumOrigem] || "";
}

function daysText(ms) {
  const days = Math.max(1, Math.floor(ms / DAY));
  return `${days} ${days === 1 ? "dia" : "dias"}`;
}

function segmentList(key, now) {
  const segment = SEGMENTS[key];
  const people = state.users.filter((user) => !user.admin && !user.desativado && segment.test(user, now));
  const recent = (user) => user.chamadoEm && now - user.chamadoEm <= CONTACT_COOLDOWN;
  const pending = people.filter((user) => !recent(user)).sort((a, b) => segment.sort(a, b, now));
  const done = people.filter(recent).sort((a, b) => b.chamadoEm - a.chamadoEm);
  return { pending, done };
}

function renderFocus() {
  const now = Date.now();
  const lists = Object.fromEntries(Object.keys(SEGMENTS).map((key) => [key, segmentList(key, now)]));
  if (!state.focus) {
    state.focus = Object.keys(SEGMENTS).find((key) => lists[key].pending.length) || "risco";
  }

  $("focus-tabs").innerHTML = Object.entries(SEGMENTS)
    .map(
      ([key, segment]) =>
        `<button data-focus="${key}" class="chip${key === state.focus ? " active" : ""}">${segment.label} · ${lists[key].pending.length}</button>`,
    )
    .join("");
  $("focus-why").textContent = SEGMENTS[state.focus].why;

  const { pending, done } = lists[state.focus];
  if (!pending.length && !done.length) {
    $("focus").innerHTML = `<div class="empty">Ninguém nesta lista agora.</div>`;
    return;
  }
  $("focus").innerHTML =
    (pending.length ? pending.map((user) => focusCard(user, now, null)).join("") : `<div class="empty">Todo mundo desta lista já foi chamado.</div>`) +
    done.map((user) => focusCard(user, now, user.chamadoEm)).join("");
}

function focusCard(user, now, calledAt) {
  const segment = SEGMENTS[state.focus];
  const text = segment.message(firstName(user.nome) || "tudo bem", user, now);
  const contact = contactLink(user, text);
  const status = calledAt
    ? `<button class="btn soft" data-focus-action="undo">Chamado ${relative(calledAt)} · desfazer</button>`
    : `<button class="btn soft" data-focus-action="done">Já chamei</button>`;
  const trial = segment.trial && !calledAt ? '<button class="btn green" data-focus-action="trial">Dar 7 dias</button>' : "";

  return `
    <article class="user${calledAt ? " called" : ""}" data-uid="${escapeHtml(user.uid)}">
      <div class="avatar">${escapeHtml(initials(user.nome || user.email))}</div>
      <div class="user-main">
        <div class="user-name"><button class="link strong" data-file="${escapeHtml(user.uid)}">${escapeHtml(user.nome || "Sem nome")}</button></div>
        <div class="user-mail">${escapeHtml(user.email)}${user.telefone ? ` · ${escapeHtml(phone(user.telefone))}` : " · sem telefone"}</div>
        <div class="user-meta"><span>${escapeHtml(segment.reason(user, now))}</span></div>
      </div>
      <div class="user-actions">${calledAt ? "" : contact}${trial}${status}</div>
    </article>`;
}

function contactLink(user, text) {
  const whats = whatsappNumber(user.telefone);
  if (whats) {
    return `<a class="btn whats" target="_blank" rel="noopener" data-contact href="https://wa.me/${whats}?text=${encodeURIComponent(text)}">Chamar no WhatsApp</a>`;
  }
  if (user.email) {
    return `<a class="btn ghost" data-contact href="mailto:${encodeURIComponent(user.email)}?subject=${encodeURIComponent("Pagô!")}&body=${encodeURIComponent(text)}">Mandar e-mail</a>`;
  }
  return "";
}

function firstName(full) {
  const first = String(full || "").trim().split(/\s+/)[0] || "";
  return first ? first[0].toUpperCase() + first.slice(1).toLowerCase() : "";
}

function whatsappNumber(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  if (digits.length === 10 || digits.length === 11) return `55${digits}`;
  if ((digits.length === 12 || digits.length === 13) && digits.startsWith("55")) return digits;
  return null;
}

async function setContacted(user, value) {
  const previous = user.chamadoEm;
  user.chamadoEm = value ? Date.now() : null;
  renderFocus();
  try {
    await api("/contacted", { uid: user.uid, value, motivo: SEGMENTS[state.focus]?.label || "" });
  } catch (error) {
    user.chamadoEm = previous;
    renderFocus();
    toast(error.message);
  }
}

$("focus-tabs").addEventListener("click", (event) => {
  const chip = event.target.closest("[data-focus]");
  if (!chip) return;
  state.focus = chip.dataset.focus;
  renderFocus();
});

$("focus").addEventListener("click", async (event) => {
  const fileLink = event.target.closest("[data-file]");
  if (fileLink) {
    openFile(fileLink.dataset.file);
    return;
  }
  const card = event.target.closest(".user");
  if (!card) return;
  const user = state.users.find((item) => item.uid === card.dataset.uid);
  if (!user) return;
  const label = user.nome || user.email;

  if (event.target.closest("[data-contact]")) {
    setTimeout(() => {
      if (confirm(`Marcar ${label} como chamado?`)) setContacted(user, true);
    }, 600);
    return;
  }
  const button = event.target.closest("[data-focus-action]");
  if (!button) return;
  const action = button.dataset.focusAction;
  if (action === "done" || action === "undo") {
    setContacted(user, action === "done");
  } else if (action === "trial") {
    if (!confirm(`Dar 7 dias de Premium para ${label}?`)) return;
    await run(button, () => api("/premium", { uid: user.uid, days: 7 }), (data) =>
      `Premium até ${dateFmt.format(data.premiumAte)} para ${label}. Avise no WhatsApp.`,
    );
  }
});

function matches(user) {
  const now = Date.now();
  if (state.filter === "online" && !(user.ultimoAcesso && now - user.ultimoAcesso <= ONLINE_MS)) return false;
  if (state.filter === "premium" && !user.premiumAtivo) return false;
  if (state.filter === "free" && user.premiumAtivo) return false;
  if (state.filter === "expiring" && !(user.premiumAtivo && user.premiumAte - now <= 7 * DAY)) return false;
  if (!state.query) return true;
  const digits = state.query.replace(/\D/g, "");
  return (
    String(user.nome).toLowerCase().includes(state.query) ||
    String(user.email).toLowerCase().includes(state.query) ||
    (digits.length >= 3 && String(user.telefone).includes(digits))
  );
}

function renderUsers() {
  const list = state.users.filter(matches);
  $("count").textContent = `(${list.length}${list.length !== state.users.length ? ` de ${state.users.length}` : ""})`;
  if (!list.length) {
    $("users").innerHTML = `<div class="empty">Ninguém por aqui.</div>`;
    return;
  }
  $("users").innerHTML = list.map(userCard).join("");
}

function planBadge(user) {
  const now = Date.now();
  const expiring = user.premiumAtivo && user.premiumAte - now <= 7 * DAY;
  const origin = originLabel(user);
  if (user.premiumAtivo) {
    return `<span class="badge ${expiring ? "expiring" : "premium"}">Premium até ${dateFmt.format(user.premiumAte)}${origin ? ` · ${origin}` : ""}</span>`;
  }
  if (user.premiumAte) return `<span class="badge">Premium venceu ${dateFmt.format(user.premiumAte)}</span>`;
  return `<span class="badge">Grátis</span>`;
}

function userCard(user) {
  const now = Date.now();
  const online = user.ultimoAcesso && now - user.ultimoAcesso <= ONLINE_MS;
  const uso = user.uso
    ? `${user.uso.lancamentos} lançamentos · ${user.uso.pagamentos} pagamentos · ${user.uso.boletos} boletos`
    : "";
  const meta = [
    `Último acesso: ${online ? "online agora" : relative(user.ultimoAcesso)}`,
    user.criadoEm ? `Cadastro: ${dateFmt.format(user.criadoEm)}` : "",
    user.plataforma ? platformName(user.plataforma) : "",
    user.telefone ? phone(user.telefone) : "",
    uso,
  ].filter(Boolean);

  return `
    <article class="user" data-uid="${escapeHtml(user.uid)}">
      <div class="avatar${online ? " online" : ""}">${escapeHtml(initials(user.nome || user.email))}</div>
      <div class="user-main">
        <div class="user-name"><button class="link strong" data-file="${escapeHtml(user.uid)}">${escapeHtml(user.nome || (user.admin ? "Administrador" : "Sem nome"))}</button> ${planBadge(user)}${user.admin ? ' <span class="badge admin">admin</span>' : ""}</div>
        <div class="user-mail">${escapeHtml(user.email)}</div>
        <div class="user-meta">${meta.map((item) => `<span>${escapeHtml(item)}</span>`).join("")}</div>
      </div>
      <div class="user-actions">${premiumControls(user)}</div>
    </article>`;
}

function premiumControls(user) {
  return `
    <select aria-label="Dias de Premium">
      <option value="7">7 dias</option>
      <option value="30" selected>30 dias</option>
      <option value="90">90 dias</option>
      <option value="365">1 ano</option>
    </select>
    <button class="btn green" data-action="premium">${user.premiumAtivo ? "Somar" : "Dar Premium"}</button>
    ${user.premiumAtivo ? '<button class="btn soft" data-action="revoke">Tirar</button>' : ""}
    ${user.admin ? "" : '<button class="btn danger" data-action="delete">Excluir</button>'}`;
}

async function handlePremiumAction(event, uid, container) {
  const button = event.target.closest("[data-action]");
  if (!button) return false;
  const user = state.users.find((item) => item.uid === uid);
  if (!user) return true;
  const label = user.nome || user.email;
  const action = button.dataset.action;

  if (action === "premium") {
    const days = Number(container.querySelector("select").value);
    const verb = user.premiumAtivo ? `Somar ${days} dias ao Premium de` : `Dar ${days} dias de Premium para`;
    if (!confirm(`${verb} ${label}?`)) return true;
    await run(button, () => api("/premium", { uid, days }), (data) => `Premium até ${dateFmt.format(data.premiumAte)} para ${label}.`);
  } else if (action === "revoke") {
    if (!confirm(`Tirar o Premium de ${label} agora?`)) return true;
    await run(button, () => api("/revoke", { uid }), () => `Premium removido de ${label}.`);
  } else if (action === "delete") {
    const typed = prompt(
      `Excluir ${label} apaga o login e TODOS os dados (caderneta, pagamentos, boletos). Não tem volta.\n\nDigite EXCLUIR para confirmar:`,
    );
    if (String(typed || "").trim().toUpperCase() !== "EXCLUIR") return true;
    await run(button, () => api("/delete", { uid }), () => `${label} foi excluído.`);
    closeLayer($("drawer"));
  }
  return true;
}

$("users").addEventListener("click", async (event) => {
  const fileLink = event.target.closest("[data-file]");
  if (fileLink) {
    openFile(fileLink.dataset.file);
    return;
  }
  const card = event.target.closest(".user");
  if (card) await handlePremiumAction(event, card.dataset.uid, card);
});

async function run(button, task, message) {
  button.disabled = true;
  try {
    const data = await task();
    toast(message(data));
    await load({ quiet: true });
    if (state.file) await openFile(state.file, { keep: true });
  } catch (error) {
    toast(error.message);
  } finally {
    button.disabled = false;
  }
}

async function openFile(uid, { keep = false } = {}) {
  if (!uid) return;
  state.file = uid;
  $("drawer").hidden = false;
  if (!keep) $("drawer-content").innerHTML = `<div class="empty">Carregando ficha...</div>`;
  try {
    const file = await api(`/user?uid=${encodeURIComponent(uid)}`);
    if (state.file !== uid) return;
    renderFile(file);
  } catch (error) {
    $("drawer-content").innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

function renderFile(file) {
  const user = state.users.find((item) => item.uid === file.uid) || { ...file, uso: file.uso };
  const now = Date.now();
  const contact = contactLink(file, `Oi ${firstName(file.nome) || "tudo bem"}, aqui é o ${SIGNATURE}, do Pagô! `);
  const maxMonth = Math.max(1, ...file.uso.porMes.map((month) => month.total));
  const checks = [
    ["Chave PIX", file.configurou.chavePix],
    ["Banco", file.configurou.banco],
    ["Mensagem de cobrança própria", file.configurou.mensagemPropria],
    ["Lembretes ligados", file.configurou.lembretes],
    ["Biometria", file.configurou.biometria],
  ];

  $("drawer-content").innerHTML = `
    <div class="file-head">
      <div class="avatar big">${escapeHtml(initials(file.nome || file.email))}</div>
      <div>
        <h2>${escapeHtml(file.nome || "Sem nome")}</h2>
        <div class="muted">${escapeHtml(file.email)}${file.telefone ? ` · ${escapeHtml(phone(file.telefone))}` : ""}</div>
        <div class="file-badges">${planBadge(file)}${file.plataforma ? `<span class="badge">${platformName(file.plataforma)}</span>` : ""}${
          file.chamadoEm ? `<span class="badge">chamado ${relative(file.chamadoEm)}</span>` : ""
        }</div>
      </div>
    </div>
    <div class="file-actions">${contact}</div>

    <div class="file-grid">
      <div class="mini"><span>Cadastro</span><b>${file.criadoEm ? dateFmt.format(file.criadoEm) : "—"}</b></div>
      <div class="mini"><span>Último acesso</span><b>${relative(file.ultimoAcesso || file.ultimoLogin)}</b></div>
      <div class="mini"><span>Lançamentos</span><b>${file.uso.lancamentos}</b><em>${file.uso.emAberto} em aberto</em></div>
      <div class="mini"><span>Pagamentos</span><b>${file.uso.pagamentos}</b></div>
      <div class="mini"><span>Boletos</span><b>${file.uso.boletos}</b><em>${file.uso.boletosEmAberto} em aberto</em></div>
    </div>

    <h3>Lançamentos por mês</h3>
    <div class="chart small-chart">${file.uso.porMes
      .map(
        (month) => `<div class="bar${month.total ? "" : " zero"}"><span>${month.total || ""}</span><i style="height:${Math.max(3, (month.total / maxMonth) * 60)}px"></i><span>${monthFmt.format(month.mes).replace(".", "")}</span></div>`,
      )
      .join("")}</div>

    <h3>O que configurou no app</h3>
    <div class="checks">${checks.map(([label, ok]) => `<span class="check ${ok ? "ok" : ""}">${ok ? "✓" : "–"} ${label}</span>`).join("")}</div>

    <h3>Premium</h3>
    <div class="user-actions left" data-premium-box>${premiumControls(user)}</div>
    ${
      file.assinaturas.length
        ? file.assinaturas
            .map(
              (sub) =>
                `<p class="small">Assinatura Play: <b>${subState(sub)}</b>${sub.venceEm ? ` · vale até ${dateFmt.format(sub.venceEm)}` : ""}${sub.renovaSozinha ? " · renova sozinha" : ""}${sub.teste ? " · teste" : ""}${sub.verificada ? "" : " · não conferida com a Google"}</p>`,
            )
            .join("")
        : `<p class="muted small">Nenhuma assinatura da Play ligada a esta conta.</p>`
    }

    <h3>Histórico</h3>
    <div class="feed">${
      file.historico.length
        ? file.historico
            .map(
              (item) =>
                `<div class="feed-item ${item.origem}"><span class="feed-dot"></span><div>${
                  item.origem === "play"
                    ? `Play: ${escapeHtml(EVENT_LABELS[item.tipo] || item.tipo)}${item.detalhe ? ` · ${escapeHtml(item.detalhe)}` : ""}${item.teste ? " · teste" : ""}`
                    : `${escapeHtml(item.por || "admin")} ${escapeHtml(ACTION_LABELS[item.tipo] || item.tipo)}${item.detalhe ? `: ${escapeHtml(item.detalhe)}` : ""}`
                }</div><span class="muted small">${item.em ? dateTimeFmt.format(item.em) : ""}</span></div>`,
            )
            .join("")
        : `<div class="empty">Nada registrado ainda.</div>`
    }</div>

    <h3>Anotações</h3>
    <form id="note-form" class="note-form">
      <textarea id="note-text" rows="3" maxlength="2000" placeholder="Ex.: pediu ajuda com boleto, prometeu assinar no fim do mês..."></textarea>
      <button class="btn primary" type="submit">Salvar anotação</button>
    </form>
    <div class="notes">${
      file.anotacoes.length
        ? file.anotacoes
            .map(
              (note) =>
                `<div class="note" data-note="${escapeHtml(note.id)}"><p>${escapeHtml(note.texto).replace(/\n/g, "<br>")}</p><div class="muted small">${note.em ? dateTimeFmt.format(note.em) : ""} · ${escapeHtml(note.por || "")} <button class="link danger-text" data-note-delete>apagar</button></div></div>`,
            )
            .join("")
        : `<div class="muted small">Nenhuma anotação.</div>`
    }</div>`;

  $("note-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const text = $("note-text").value.trim();
    if (!text) return;
    const button = event.target.querySelector("button");
    button.disabled = true;
    try {
      await api("/note", { uid: file.uid, text });
      toast("Anotação salva.");
      await openFile(file.uid, { keep: true });
    } catch (error) {
      toast(error.message);
      button.disabled = false;
    }
  });
}

$("drawer-content").addEventListener("click", async (event) => {
  const uid = state.file;
  if (!uid) return;
  const box = event.target.closest("[data-premium-box]");
  if (box) {
    await handlePremiumAction(event, uid, box);
    return;
  }
  if (event.target.closest("[data-note-delete]")) {
    const note = event.target.closest("[data-note]");
    if (!confirm("Apagar esta anotação?")) return;
    try {
      await api("/note/delete", { uid, id: note.dataset.note });
      await openFile(uid, { keep: true });
    } catch (error) {
      toast(error.message);
    }
  }
});

function subState(sub) {
  return (
    {
      SUBSCRIPTION_STATE_ACTIVE: "ativa",
      SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "em carência",
      SUBSCRIPTION_STATE_ON_HOLD: "suspensa",
      SUBSCRIPTION_STATE_PAUSED: "pausada",
      SUBSCRIPTION_STATE_CANCELED: "cancelada (vale até o fim do período)",
      SUBSCRIPTION_STATE_EXPIRED: "expirada",
    }[sub.estado] || (sub.verificada ? sub.estado || "?" : "registrada")
  );
}

async function loadLog() {
  $("log").innerHTML = `<div class="empty">Carregando...</div>`;
  try {
    const data = await api("/log");
    $("log").innerHTML = data.itens.length
      ? data.itens
          .map(
            (item) => `
        <div class="feed-item">
          <span class="feed-dot"></span>
          <div><b>${escapeHtml(item.por || "admin")}</b> ${escapeHtml(ACTION_LABELS[item.acao] || item.acao)}${
            item.alvo ? ` · ${item.uid ? `<button class="link" data-file="${escapeHtml(item.uid)}">${escapeHtml(item.alvo)}</button>` : escapeHtml(item.alvo)}` : ""
          }${item.detalhe ? ` <span class="muted">(${escapeHtml(item.detalhe)})</span>` : ""}</div>
          <span class="muted small">${item.em ? dateTimeFmt.format(item.em) : ""}</span>
        </div>`,
          )
          .join("")
      : `<div class="empty">Nenhuma ação registrada ainda.</div>`;
  } catch (error) {
    $("log").innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

$("log").addEventListener("click", (event) => {
  const link = event.target.closest("[data-file]");
  if (link) openFile(link.dataset.file);
});

function exportCsv() {
  const header = [
    "Nome", "E-mail", "Telefone", "Cadastro", "Último acesso", "Plataforma", "Plano", "Premium até",
    "Origem do Premium", "Lançamentos", "Pagamentos", "Boletos", "Chamado em", "Admin",
  ];
  const rows = state.users.map((user) => [
    user.nome,
    user.email,
    user.telefone,
    user.criadoEm ? dateFmt.format(user.criadoEm) : "",
    user.ultimoAcesso ? dateTimeFmt.format(user.ultimoAcesso) : "",
    platformName(user.plataforma || ""),
    user.premiumAtivo ? "Premium" : "Grátis",
    user.premiumAte ? dateFmt.format(user.premiumAte) : "",
    originLabel(user),
    user.uso?.lancamentos ?? "",
    user.uso?.pagamentos ?? "",
    user.uso?.boletos ?? "",
    user.chamadoEm ? dateFmt.format(user.chamadoEm) : "",
    user.admin ? "sim" : "",
  ]);
  const csv = [header, ...rows]
    .map((row) => row.map((cell) => `"${String(cell ?? "").replace(/"/g, '""')}"`).join(";"))
    .join("\r\n");
  const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = `pago-usuarios-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(link.href), 1000);
}

async function openSecurity() {
  $("modal").hidden = false;
  $("modal-content").innerHTML = `<div class="empty">Carregando...</div>`;
  try {
    const status = await api("/2fa/status");
    if (status.ativo) {
      $("modal-content").innerHTML = `
        <h2>Segurança</h2>
        <p><span class="badge premium">Segundo fator ligado</span></p>
        <p class="muted small">Ao entrar, o painel pede o código do aplicativo autenticador. A sessão vale 12 horas neste navegador.</p>
        <form id="disable-form" class="note-form">
          <label>Para desligar, digite um código atual<input id="disable-code" inputmode="numeric" maxlength="6" required /></label>
          <button class="btn danger" type="submit">Desligar segundo fator</button>
        </form>`;
      $("disable-form").addEventListener("submit", async (event) => {
        event.preventDefault();
        try {
          await api("/2fa/disable", { code: $("disable-code").value });
          sessionStorage.removeItem(SESSION_KEY);
          toast("Segundo fator desligado.");
          openSecurity();
        } catch (error) {
          toast(error.message);
        }
      });
      return;
    }
    $("modal-content").innerHTML = `
      <h2>Ligar o segundo fator</h2>
      <p class="muted small">Além da senha, o painel vai pedir um código de 6 números que muda a cada 30 segundos. Use o Google Authenticator ou o Microsoft Authenticator no celular.</p>
      <button class="btn primary" id="setup-btn">Gerar código QR</button>
      <div id="setup-area"></div>`;
    $("setup-btn").addEventListener("click", startSetup);
  } catch (error) {
    if (!error.twofa) $("modal-content").innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

async function startSetup() {
  $("setup-btn").disabled = true;
  try {
    const data = await api("/2fa/setup", {});
    let qr = "";
    try {
      const { default: QRCode } = await import("https://cdn.jsdelivr.net/npm/qrcode@1.5.4/+esm");
      qr = `<img class="qr" alt="Código QR" src="${await QRCode.toDataURL(data.uri, { margin: 1, width: 220 })}" />`;
    } catch (_) {
      qr = "";
    }
    $("setup-area").innerHTML = `
      <ol class="steps">
        <li>No aplicativo autenticador, toque em adicionar conta e leia o código QR${qr ? `:<br>${qr}` : " (não carregou: use a chave abaixo)"}.</li>
        <li>Ou digite a chave manualmente: <code>${escapeHtml(data.secret.replace(/(.{4})/g, "$1 ").trim())}</code></li>
        <li>Digite o código que aparecer no aplicativo:</li>
      </ol>
      <form id="enable-form" class="note-form">
        <input id="enable-code" inputmode="numeric" maxlength="6" placeholder="000000" required />
        <button class="btn primary" type="submit">Ligar</button>
      </form>
      <p class="muted small">Guarde a chave num lugar seguro. Se perder o celular, apague o documento da sua conta em AdminSecurity no Firestore para desligar.</p>`;
    $("enable-form").addEventListener("submit", async (event) => {
      event.preventDefault();
      try {
        const result = await api("/2fa/enable", { code: $("enable-code").value });
        sessionStorage.setItem(SESSION_KEY, result.sessao);
        toast("Segundo fator ligado.");
        securityChecked = false;
        checkSecurityBanner();
        openSecurity();
      } catch (error) {
        toast(error.message);
      }
    });
  } catch (error) {
    toast(error.message);
    $("setup-btn").disabled = false;
  }
}

function relative(ms) {
  if (!ms) return "nunca";
  const diff = Date.now() - ms;
  const min = Math.round(diff / 60000);
  if (min < 60) return `há ${Math.max(1, min)} min`;
  const hours = Math.round(min / 60);
  if (hours < 24) return `há ${hours} h`;
  const days = Math.round(hours / 24);
  if (days < 30) return `há ${days} ${days === 1 ? "dia" : "dias"}`;
  return dateFmt.format(ms);
}

const SP_OFFSET = 3 * 60 * 60 * 1000;

function startOfMonth(ms) {
  const local = new Date(ms - SP_OFFSET);
  return Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1) + SP_OFFSET;
}

function startOfWeek(ms) {
  const local = new Date(ms - SP_OFFSET);
  const weekday = (local.getUTCDay() + 6) % 7;
  return Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() - weekday) + SP_OFFSET;
}

function dayId(ms) {
  return new Date(ms - SP_OFFSET).toISOString().slice(0, 10);
}

function platformName(value) {
  return { android: "Android", iOS: "iPhone", web: "Web", macOS: "Mac", windows: "Windows" }[value] || value;
}

function phone(raw) {
  const digits = String(raw).replace(/\D/g, "");
  if (digits.length === 11) return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`;
  if (digits.length === 10) return `(${digits.slice(0, 2)}) ${digits.slice(2, 6)}-${digits.slice(6)}`;
  return raw;
}

function initials(text) {
  const parts = String(text).trim().split(/[\s@.]+/).filter(Boolean);
  return ((parts[0]?.[0] || "?") + (parts[1]?.[0] || "")).toUpperCase();
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[char]);
}

let toastTimer;
function toast(text) {
  const el = $("toast");
  el.textContent = text;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 3200);
}
