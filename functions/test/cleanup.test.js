const test = require("node:test");
const assert = require("node:assert/strict");
const { planCleanup, contactKey } = require("../cleanup");

const DAY = 86400000;
const NOW = Date.parse("2026-11-20T12:00:00Z");
const debt = (id, extra = {}) => ({
  id,
  data: { nome: "Zeca", telefone: "(21) 97777-6666", status_pago: true, ...extra },
});
const pay = (id, debtId, daysAgo, extra = {}) => ({
  id,
  data: { debt_id: debtId, data: NOW - daysAgo * DAY, ...extra },
});

test("apaga caderneta quitada há 7 dias ou mais, com pagamentos", () => {
  const plan = planCleanup({
    debts: [debt("a"), debt("b")],
    payments: [pay("p1", "a", 12), pay("p2", "b", 8)],
    now: NOW,
  });
  assert.equal(plan.length, 1);
  assert.deepEqual(plan[0].debtIds.sort(), ["a", "b"]);
  assert.deepEqual(plan[0].paymentIds.sort(), ["p1", "p2"]);
});

test("espera 7 dias contados do último pagamento", () => {
  const plan = planCleanup({
    debts: [debt("a"), debt("b")],
    payments: [pay("p1", "a", 30), pay("p2", "b", 6)],
    now: NOW,
  });
  assert.equal(plan.length, 0);
});

test("não apaga se algum lançamento do cliente ainda está em aberto", () => {
  const plan = planCleanup({
    debts: [debt("a"), debt("b", { status_pago: false })],
    payments: [pay("p1", "a", 30)],
    now: NOW,
  });
  assert.equal(plan.length, 0);
});

test("respeita o 'manter' e ignora pagamento estornado ao contar o prazo", () => {
  assert.equal(
    planCleanup({ debts: [debt("a", { manter: true })], payments: [pay("p1", "a", 30)], now: NOW }).length,
    0,
  );
  const plan = planCleanup({
    debts: [debt("a")],
    payments: [pay("p1", "a", 30), pay("p2", "a", 2, { estornado_em: NOW })],
    now: NOW,
  });
  assert.equal(plan.length, 1);
});

test("chave de contato igual à do app", () => {
  assert.equal(contactKey({ telefone: "(21) 97777-6666", nome: "Zeca" }), "p:21977776666");
  assert.equal(contactKey({ telefone: "", nome: "  José  Ávila " }), "n:jose avila");
});
