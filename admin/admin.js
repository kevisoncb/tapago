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

const auth = getAuth(initializeApp(firebaseConfig));
const $ = (id) => document.getElementById(id);
const money = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const dateFmt = new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "2-digit", year: "2-digit" });
const dayFmt = new Intl.DateTimeFormat("pt-BR", { day: "2-digit" });

const state = { users: [], filter: "all", query: "", loading: false, timer: null };

onAuthStateChanged(auth, (user) => {
  $("login").hidden = !!user;
  $("app").hidden = !user;
  clearInterval(state.timer);
  if (user) {
    load();
    state.timer = setInterval(() => {
      if (document.visibilityState === "visible") load({ quiet: true });
    }, AUTO_REFRESH_MS);
  }
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

$("logout").addEventListener("click", () => signOut(auth));
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
$("refresh").addEventListener("click", () => load());
$("search").addEventListener("input", (event) => {
  state.query = event.target.value.trim().toLowerCase();
  renderUsers();
});
$("filters").addEventListener("click", (event) => {
  const chip = event.target.closest("[data-filter]");
  if (!chip) return;
  state.filter = chip.dataset.filter;
  document.querySelectorAll(".chip").forEach((item) => item.classList.toggle("active", item === chip));
  renderUsers();
});

async function api(path, body, attempt = 1) {
  const token = await auth.currentUser.getIdToken();
  let response;
  try {
    response = await fetch(`${API}${path}`, {
      method: body ? "POST" : "GET",
      headers: {
        authorization: `Bearer ${token}`,
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
    const error = new Error(data.message || "Falha no servidor.");
    error.status = response.status;
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
    state.users = data.users || [];
    renderStats(data.stats);
    renderChart(data.stats.cadastros14d || []);
    renderUsers();
    $("updated").textContent = `Atualizado ${new Date(data.geradoEm).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}`;
  } catch (error) {
    if (error.status === 403) {
      toast("Esta conta não é administradora.");
      await signOut(auth);
      $("login-error").textContent = "Esta conta não é administradora.";
    } else if (!quiet) {
      $("users").innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
    }
  } finally {
    state.loading = false;
    $("refresh").disabled = false;
  }
}

function renderStats(stats) {
  const cards = [
    { label: "Online agora", value: stats.online, hint: "usaram nos últimos 5 min", hero: true, dot: true },
    { label: "Ativos 24h", value: stats.ativos24h, hint: `${stats.ativos7d} em 7 dias · ${stats.ativos30d} em 30` },
    { label: "Cadastros", value: stats.total, hint: `+${stats.novos7d} nos últimos 7 dias` },
    { label: "Premium ativos", value: stats.premium, hint: `${stats.premiumPagantes} pagantes · ${stats.premiumCortesia} cortesia` },
    { label: "Receita estimada/mês", value: money.format(stats.receitaEstimada), hint: "pagantes × R$ 39,90 (bruto)" },
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

function userCard(user) {
  const now = Date.now();
  const online = user.ultimoAcesso && now - user.ultimoAcesso <= ONLINE_MS;
  const expiring = user.premiumAtivo && user.premiumAte - now <= 7 * DAY;
  const origin = { admin: "cortesia", pix: "PIX", play: "Play" }[user.premiumOrigem] || "";
  const plan = user.premiumAtivo
    ? `<span class="badge ${expiring ? "expiring" : "premium"}">Premium até ${dateFmt.format(user.premiumAte)}${origin ? ` · ${origin}` : ""}</span>`
    : user.premiumAte
      ? `<span class="badge">Premium venceu ${dateFmt.format(user.premiumAte)}</span>`
      : `<span class="badge">Grátis</span>`;
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
        <div class="user-name">${escapeHtml(user.nome || (user.admin ? "Administrador" : "Sem nome"))} ${plan}${user.admin ? ' <span class="badge admin">admin</span>' : ""}</div>
        <div class="user-mail">${escapeHtml(user.email)}</div>
        <div class="user-meta">${meta.map((item) => `<span>${escapeHtml(item)}</span>`).join("")}</div>
      </div>
      <div class="user-actions">
        <select aria-label="Dias de Premium">
          <option value="7">7 dias</option>
          <option value="30" selected>30 dias</option>
          <option value="90">90 dias</option>
          <option value="365">1 ano</option>
        </select>
        <button class="btn green" data-action="premium">${user.premiumAtivo ? "Somar" : "Dar Premium"}</button>
        ${user.premiumAtivo ? '<button class="btn soft" data-action="revoke">Tirar</button>' : ""}
        ${user.admin ? "" : '<button class="btn danger" data-action="delete">Excluir</button>'}
      </div>
    </article>`;
}

$("users").addEventListener("click", async (event) => {
  const button = event.target.closest("[data-action]");
  if (!button) return;
  const card = button.closest(".user");
  const user = state.users.find((item) => item.uid === card.dataset.uid);
  if (!user) return;
  const label = user.nome || user.email;
  const action = button.dataset.action;

  if (action === "premium") {
    const days = Number(card.querySelector("select").value);
    const verb = user.premiumAtivo ? `Somar ${days} dias ao Premium de` : `Dar ${days} dias de Premium para`;
    if (!confirm(`${verb} ${label}?`)) return;
    await run(button, () => api("/premium", { uid: user.uid, days }), (data) =>
      `Premium até ${dateFmt.format(data.premiumAte)} para ${label}.`,
    );
  } else if (action === "revoke") {
    if (!confirm(`Tirar o Premium de ${label} agora?`)) return;
    await run(button, () => api("/revoke", { uid: user.uid }), () => `Premium removido de ${label}.`);
  } else if (action === "delete") {
    const typed = prompt(
      `Excluir ${label} apaga o login e TODOS os dados (caderneta, pagamentos, boletos). Não tem volta.\n\nDigite EXCLUIR para confirmar:`,
    );
    if (String(typed || "").trim().toUpperCase() !== "EXCLUIR") return;
    await run(button, () => api("/delete", { uid: user.uid }), () => `${label} foi excluído.`);
  }
});

async function run(button, task, message) {
  button.disabled = true;
  try {
    const data = await task();
    toast(message(data));
    await load({ quiet: true });
  } catch (error) {
    toast(error.message);
  } finally {
    button.disabled = false;
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
