// Dados fictícios para pré-visualizar o painel sem Firebase. Só é carregado pela
// cópia montada por tool/admin-preview.sh; o painel de produção não usa este arquivo.
const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();

let seed = 20261026;
const rand = () => {
  seed = (seed * 1664525 + 1013904223) % 4294967296;
  return seed / 4294967296;
};
const pick = (list) => list[Math.floor(rand() * list.length)];
const dayId = (ms) => new Date(ms).toISOString().slice(0, 10);
const startOfMonth = (ms) => {
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth(), 1).getTime();
};
const addMonths = (ms, n) => {
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth() + n, 1).getTime();
};

const NAMES = ["Marina Souza", "Carlos Lima", "Ana Paula", "Rogério Alves", "Fernanda Costa", "João Batista", "Luciana Reis", "Pedro Henrique", "Camila Duarte", "Tiago Moreira", "Patrícia Gomes", "Eduardo Nunes", "Sônia Ribeiro", "Marcos Vinícius", "Aline Barros", "Roberto Dias"];
const PRICE = 19.9;

function buildUsers() {
  const users = [];
  for (let i = 0; i < 180; i += 1) {
    const age = Math.floor(rand() * 75);
    const criadoEm = NOW - age * DAY - Math.floor(rand() * DAY);
    const platform = rand() < 0.62 ? "android" : rand() < 0.9 ? "iOS" : "web";
    const active = rand() < 0.55;
    const ultimoAcesso = active ? NOW - Math.floor(rand() * 9 * DAY) : NOW - (9 + Math.floor(rand() * 40)) * DAY;
    const premium = rand() < 0.14;
    const origem = premium ? (platform === "iOS" ? "apple" : rand() < 0.88 ? "play" : "admin") : "";
    users.push({
      uid: `demo${i}`,
      nome: `${pick(NAMES)}`,
      email: `pessoa${i}@exemplo.com`,
      telefone: `1199${String(1000000 + i * 137).slice(0, 7)}`,
      criadoEm,
      ultimoAcesso: Math.max(ultimoAcesso, criadoEm),
      plataforma: platform,
      premiumAte: premium ? NOW + (3 + Math.floor(rand() * 25)) * DAY : null,
      premiumAtivo: premium,
      premiumOrigem: origem,
      admin: false,
      desativado: false,
      chamadoEm: null,
      uso: { lancamentos: Math.floor(rand() * rand() * 60), pagamentos: Math.floor(rand() * 30), boletos: Math.floor(rand() * 8) },
    });
  }
  return users;
}

const users = buildUsers();

function buildHistory() {
  const items = [];
  let total = 40;
  let ativos = 14;
  let pagantes = 1;
  for (let i = 69; i >= 0; i -= 1) {
    total += Math.round(rand() * 3.4);
    ativos = Math.max(8, ativos + Math.round((rand() - 0.42) * 3));
    if (rand() < 0.16) pagantes += 1;
    items.push({ dia: dayId(NOW - i * DAY), total, ativos7d: ativos, ativos30d: ativos + 12, premium: pagantes + 1, premiumPagantes: pagantes, android: Math.round(total * 0.62), ios: Math.round(total * 0.28) });
  }
  return items;
}

function buildRevenue() {
  const eventos = [];
  const types = ["COMPRA", "RENOVADA", "RENOVADA", "CANCELADA", "COMPRA", "SUSPENSA"];
  for (let i = 0; i < 36; i += 1) {
    const tipo = pick(types);
    const loja = rand() < 0.6 ? "play" : "app_store";
    const charge = ["COMPRA", "RENOVADA"].includes(tipo);
    const user = pick(users.filter((u) => u.premiumAtivo));
    eventos.push({ id: `e${i}`, uid: user.uid, nome: user.nome, tipo, cobranca: charge, valor: charge ? PRICE : 0, teste: false, loja, em: NOW - Math.floor(rand() * 40 * DAY) });
  }
  eventos.sort((a, b) => b.em - a.em);
  const fee = { play: 0.15, app_store: 0.15 };
  const period = (from, to) => {
    const list = eventos.filter((e) => e.em >= from && e.em < to);
    const porLoja = {};
    for (const store of ["play", "app_store"]) {
      const part = list.filter((e) => e.loja === store);
      const charges = part.filter((e) => e.cobranca);
      const bruto = Math.round(charges.reduce((s, e) => s + e.valor, 0) * 100) / 100;
      porLoja[store] = {
        bruto, liquido: Math.round(bruto * (1 - fee[store]) * 100) / 100, cobrancas: charges.length,
        novas: part.filter((e) => e.tipo === "COMPRA").length, renovacoes: part.filter((e) => e.tipo === "RENOVADA").length,
        cancelamentos: part.filter((e) => e.tipo === "CANCELADA").length, falhas: part.filter((e) => e.tipo === "SUSPENSA").length,
      };
    }
    const sum = (key) => Math.round(Object.values(porLoja).reduce((s, p) => s + p[key], 0) * 100) / 100;
    return { bruto: sum("bruto"), liquido: sum("liquido"), cobrancas: sum("cobrancas"), novas: sum("novas"), renovacoes: sum("renovacoes"), cancelamentos: sum("cancelamentos"), falhas: sum("falhas"), porLoja };
  };
  const monthStart = startOfMonth(NOW);
  const meses = [];
  const growth = [0.18, 0.3, 0.45, 0.62, 0.8, 1];
  growth.forEach((g, index) => {
    const start = addMonths(NOW, index - 5);
    const play = Math.round(g * 260 * 100) / 100;
    const apple = Math.round(g * 150 * 100) / 100;
    meses.push({ mes: start, play, app_store: apple, bruto: play + apple, liquido: Math.round((play + apple) * 0.85 * 100) / 100 });
  });
  return { taxaPlay: 0.15, taxas: fee, mesAtual: period(monthStart, Infinity), mesAnterior: period(addMonths(NOW, -1), monthStart), meses, eventos: eventos.slice(0, 40) };
}

function overview() {
  const people = users;
  const premium = people.filter((u) => u.premiumAtivo);
  const paying = premium.filter((u) => u.premiumOrigem !== "admin");
  const activeSince = (ms) => people.filter((u) => NOW - u.ultimoAcesso <= ms).length;
  const counts = { android: 0, ios: 0, web: 0, outras: 0, semDado: 0 };
  people.forEach((u) => (counts[u.plataforma.toLowerCase() === "ios" ? "ios" : u.plataforma] += 1));
  const origins = { play: 0, apple: 0, pix: 0, admin: 0 };
  premium.forEach((u) => (origins[u.premiumOrigem] += 1));
  const signups = [];
  for (let i = 13; i >= 0; i -= 1) {
    const start = NOW - i * DAY;
    signups.push({ dia: start, total: people.filter((u) => u.criadoEm > start - DAY && u.criadoEm <= start).length });
  }
  const stats = {
    total: people.length, novos7d: people.filter((u) => NOW - u.criadoEm <= 7 * DAY).length,
    online: people.filter((u) => NOW - u.ultimoAcesso <= 5 * 60 * 1000).length + 3, ativos24h: activeSince(DAY), ativos7d: activeSince(7 * DAY), ativos30d: activeSince(30 * DAY),
    premium: premium.length, premiumPagantes: paying.length, premiumCortesia: premium.length - paying.length,
    premiumVence7d: premium.filter((u) => u.premiumAte - NOW <= 7 * DAY).length, receitaEstimada: Math.round(paying.length * PRICE * 100) / 100,
    plataformas: counts, premiumPorOrigem: origins, cadastros14d: signups,
  };
  return { geradoEm: NOW, stats, receita: buildRevenue(), historico: buildHistory(), emailLigado: true, users };
}

// ?legacy simula o servidor antigo (sem separação por loja) para testar a compatibilidade.
function legacy(data) {
  const copy = JSON.parse(JSON.stringify(data));
  delete copy.stats.plataformas;
  delete copy.stats.premiumPorOrigem;
  delete copy.receita.meses;
  delete copy.receita.taxas;
  for (const key of ["mesAtual", "mesAnterior"]) delete copy.receita[key].porLoja;
  copy.receita.eventos.forEach((event) => delete event.loja);
  copy.historico.forEach((item) => { delete item.android; delete item.ios; });
  return copy;
}

let cached = null;
export function demoApi(path) {
  if (path === "/overview") {
    cached ??= overview();
    return Promise.resolve(globalThis.location?.search.includes("legacy") ? legacy(cached) : cached);
  }
  if (path === "/2fa/status") return Promise.resolve({ ativo: true, obrigatorio: true });
  if (path === "/2fa/setup") return Promise.resolve({ secret: "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP", uri: "otpauth://totp/Pago:demo?secret=JBSWY3DPEHPK3PXP" });
  if (path === "/2fa/enable") return Promise.resolve({ ok: true, sessao: "demo" });
  if (path === "/log") return Promise.resolve({ itens: [{ em: NOW - 3600000, por: "demo@pago.app", acao: "premium", alvo: "Marina Souza", uid: "demo1", detalhe: "+30 dias" }] });
  return Promise.reject(new Error("Modo demonstração: esta ação não está disponível."));
}
