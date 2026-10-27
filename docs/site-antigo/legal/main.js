const money = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  maximumFractionDigits: 0,
});

const counters = document.querySelectorAll("[data-count]");
const io = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      const el = entry.target;
      const end = Number(el.dataset.count);
      const start = performance.now();
      const tick = (now) => {
        const p = Math.min((now - start) / 900, 1);
        el.textContent = money.format(Math.round(end * p));
        if (p < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
      io.unobserve(el);
    });
  },
  { threshold: 0.6 }
);
counters.forEach((el) => io.observe(el));

const script = [
  { side: "in", text: "Oi João, tudo bem?" },
  {
    side: "out",
    text: "Oi Ricardo, passando só para atualizar a caderneta. Ficou R$ 1.450, vence hoje. Quando puder, me confirma?",
  },
  { side: "in", text: "Vou pagar no PIX agora." },
  { side: "out", text: "Chave PIX: joao.dinamico@email.com" },
  {
    side: "in",
    text: "Enviei. Valeu!",
    pix: {
      valor: "R$ 1.450,00",
      de: "Ricardo Carvalho",
      para: "João",
      chave: "joao.dinamico@email.com",
      quando: "05/10/2026 às 03:05",
      id: "E4a92c31b8f0d7e1",
    },
  },
];

const chat = document.getElementById("chat");

function typing() {
  const el = document.createElement("div");
  el.className = "typing";
  el.innerHTML = "<i></i><i></i><i></i>";
  chat.appendChild(el);
  return el;
}

function wait(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function row(label, value) {
  const line = document.createElement("div");
  line.className = "pix-row";
  const k = document.createElement("span");
  k.textContent = label;
  const v = document.createElement("strong");
  v.textContent = value;
  line.append(k, v);
  return line;
}

function buildPixReceipt(pix) {
  const card = document.createElement("article");
  card.className = "pix-receipt";
  card.setAttribute("aria-label", "Comprovante PIX");

  const head = document.createElement("header");
  head.className = "pix-receipt-head";
  const mark = document.createElement("span");
  mark.className = "pix-mark";
  mark.textContent = "PIX";
  const status = document.createElement("p");
  status.textContent = "Transferência concluída";
  head.append(mark, status);

  const amount = document.createElement("p");
  amount.className = "pix-amount";
  amount.textContent = pix.valor;

  const when = document.createElement("p");
  when.className = "pix-when";
  when.textContent = pix.quando;

  const body = document.createElement("div");
  body.className = "pix-receipt-body";
  body.append(
    row("De", pix.de),
    row("Para", pix.para),
    row("Chave", pix.chave),
    row("ID", pix.id)
  );

  card.append(head, amount, when, body);
  return card;
}

function addBubble(line) {
  const bubble = document.createElement("div");
  bubble.className = `bubble ${line.side}`;
  if (line.pix) {
    bubble.classList.add("bubble-media");
    bubble.append(buildPixReceipt(line.pix));
    if (line.text) {
      const cap = document.createElement("p");
      cap.className = "bubble-caption";
      cap.textContent = line.text;
      bubble.append(cap);
    }
  } else {
    bubble.textContent = line.text;
  }
  chat.appendChild(bubble);
  chat.scrollTop = chat.scrollHeight;
}

async function playChat() {
  if (!chat) return;
  chat.innerHTML = "";
  resetDemoCaderneta();
  for (const line of script) {
    const dots = typing();
    if (line.side === "out") dots.style.marginLeft = "auto";
    await wait(line.pix ? 1200 : 900);
    dots.remove();
    addBubble(line);
    await wait(line.pix ? 2400 : 700);
  }
  await playAbateOnPhone();
  await wait(2800);
  playChat();
}

function resetDemoCaderneta() {
  const saldo = document.getElementById("demo-uso-saldo");
  const btn = document.getElementById("demo-uso-abater");
  document.getElementById("demo-abate-sheet")?.remove();
  if (saldo) saldo.textContent = "R$ 1.450,00";
  if (btn) {
    btn.textContent = "Abater valor";
    btn.classList.remove("done");
  }
}

function abateOption(kind, title, hint) {
  const el = document.createElement("button");
  el.type = "button";
  el.className = "abate-opt";
  el.dataset.kind = kind;
  const strong = document.createElement("strong");
  strong.textContent = title;
  const span = document.createElement("span");
  span.textContent = hint;
  el.append(strong, span);
  return el;
}

async function playAbateOnPhone() {
  const screen = document.getElementById("demo-uso-screen");
  const saldo = document.getElementById("demo-uso-saldo");
  const btn = document.getElementById("demo-uso-abater");
  if (!screen || !saldo || !btn) return;

  document.getElementById("demo-abate-sheet")?.remove();
  const sheet = document.createElement("div");
  sheet.id = "demo-abate-sheet";
  sheet.className = "abate-sheet";
  const kicker = document.createElement("p");
  kicker.className = "abate-kicker";
  kicker.textContent = "Só você vê isso";
  const title = document.createElement("h3");
  title.textContent = "O que o cliente pagou?";
  const total = abateOption(
    "total",
    "Valor total",
    "R$ 1.450,00 · quita a caderneta"
  );
  const parte = abateOption(
    "parte",
    "Parte do valor",
    "Entrou um pedaço do combinado"
  );
  const juros = abateOption(
    "juros",
    "Somente o juros do mês",
    "Não baixa o principal"
  );
  sheet.append(kicker, title, total, parte, juros);
  screen.append(sheet);

  await wait(900);
  total.classList.add("picked");
  await wait(900);
  sheet.remove();
  saldo.textContent = "R$ 0,00";
  btn.textContent = "Quitada · valor total";
  btn.classList.add("done");
}

playChat();

const stats = document.querySelectorAll(".stat");
const statsIn = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      const el = entry.target;
      const index = [...stats].indexOf(el);
      el.style.transitionDelay = `${index * 80}ms`;
      el.classList.add("in");
      statsIn.unobserve(el);
    });
  },
  { threshold: 0.25 }
);
stats.forEach((el) => statsIn.observe(el));

stats.forEach((card) => {
  card.addEventListener("click", () => {
    stats.forEach((el) => el.classList.toggle("is-on", el === card));
  });
});

const canHover = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
if (canHover) {
  stats.forEach((card) => {
    card.addEventListener("pointermove", (event) => {
      const box = card.getBoundingClientRect();
      const x = (event.clientX - box.left) / box.width - 0.5;
      const y = (event.clientY - box.top) / box.height - 0.5;
      card.style.transform = `perspective(700px) rotateY(${x * 14}deg) rotateX(${-y * 14}deg) translateY(-8px)`;
    });
    card.addEventListener("pointerleave", () => {
      card.style.transform = "";
    });
  });
}

const deck = document.getElementById("phone-deck");
const heroPhone = document.querySelector(".hero-phone");
const saldoRua = document.getElementById("saldo-rua");
const demoLista = document.getElementById("demo-lista");
const demoHint = document.getElementById("demo-hint");
const demoNovo = document.getElementById("demo-novo");
const demoVoltar = document.getElementById("demo-voltar");
const demoSalvar = document.getElementById("demo-salvar");
const demoNome = document.getElementById("demo-nome");
const demoValor = document.getElementById("demo-valor");
const demoJuros = document.getElementById("demo-juros");

const moneyFull = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

function abrirForm() {
  deck?.classList.add("is-form");
  heroPhone?.classList.add("is-form");
  demoNome?.focus();
}

function fecharForm() {
  deck?.classList.remove("is-form");
  heroPhone?.classList.remove("is-form");
}

function parseNumero(raw) {
  const normalized = String(raw || "")
    .trim()
    .replace(/[^\d,.-]/g, "")
    .replace(/\./g, "")
    .replace(",", ".");
  if (!normalized) return 0;
  const n = Number(normalized);
  return Number.isFinite(n) ? n : 0;
}

function somarNaRua(extra) {
  if (!saldoRua) return;
  const atual = Number(saldoRua.dataset.count) || 0;
  const fim = Math.round(atual + extra);
  const inicio = performance.now();
  const tick = (now) => {
    const p = Math.min((now - inicio) / 700, 1);
    saldoRua.textContent = money.format(Math.round(atual + (fim - atual) * p));
    if (p < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
  saldoRua.dataset.count = String(fim);
}

function injetarCliente(nome, total) {
  if (!demoLista) return;
  const linha = document.createElement("div");
  linha.className = "debt";
  const quem = document.createElement("span");
  quem.textContent = nome;
  const quanto = document.createElement("strong");
  quanto.textContent = moneyFull.format(total);
  linha.append(quem, quanto);
  demoLista.append(linha);
}

function limparForm() {
  if (demoNome) demoNome.value = "";
  if (demoValor) demoValor.value = "";
  if (demoJuros) demoJuros.value = "";
}

demoHint?.addEventListener("click", abrirForm);
demoNovo?.addEventListener("click", abrirForm);
demoVoltar?.addEventListener("click", () => {
  limparForm();
  fecharForm();
});
demoSalvar?.addEventListener("click", () => {
  const nome = String(demoNome?.value || "").trim();
  const principal = parseNumero(demoValor?.value);
  const taxa = parseNumero(demoJuros?.value);
  if (!nome || principal <= 0) return;
  const total = principal * (1 + taxa / 100);
  injetarCliente(nome, total);
  somarNaRua(total);
  limparForm();
  fecharForm();
});
