const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const ROOT = path.resolve(__dirname, "..");
const DELETE = Symbol("delete");
const stamp = (value) => ({ toMillis: () => value });
const future = () => Date.now() + 30 * 86400000;

class FakeFirestore {
  constructor(seed = {}) { this.docs = new Map(Object.entries(seed)); this.writes = []; }
  collection(name) { return new Query(this, name); }
  snapshot(ref) {
    return { id: ref.id, ref, exists: this.docs.has(ref.path), data: () => this.docs.get(ref.path) };
  }
  apply(kind, ref, data, options) {
    if (kind === "delete") this.docs.delete(ref.path);
    else {
      if (kind === "create" && this.docs.has(ref.path)) throw Object.assign(new Error("exists"), { code: 6 });
      if (kind === "update" && !this.docs.has(ref.path)) throw new Error("missing update");
      const next = { ...((options?.merge || kind === "update") ? this.docs.get(ref.path) : {}), ...data };
      for (const key of Object.keys(next)) if (next[key] === DELETE) delete next[key];
      this.docs.set(ref.path, next);
    }
    this.writes.push({ kind, path: ref.path });
  }
  async runTransaction(fn) {
    const writes = [];
    const tx = {
      get: async (ref) => {
        assert.equal(writes.length, 0, "Firestore transactions read before writing");
        return ref instanceof Query ? ref.get() : this.snapshot(ref);
      },
    };
    for (const kind of ["set", "update", "create", "delete"]) {
      tx[kind] = (ref, data, options) => { writes.push([kind, ref, data, options]); return tx; };
    }
    const result = await fn(tx);
    for (const write of writes) this.apply(...write);
    return result;
  }
  batch() {
    const writes = [];
    return { delete: (ref) => writes.push(ref), commit: async () => writes.forEach(ref => this.apply("delete", ref)) };
  }
}
class Query {
  constructor(db, collection, filters = [], limit = Infinity) {
    this.db = db; this.name = collection; this.filters = filters; this.max = limit;
  }
  doc(id) { return new Ref(this.db, `${this.name}/${id}`); }
  where(field, operator, value) { return new Query(this.db, this.name, [...this.filters, [field, operator, value]], this.max); }
  limit(n) { return new Query(this.db, this.name, this.filters, n); }
  async add(data) { const ref = this.doc(`auto-${this.db.docs.size}`); await ref.set(data); return ref; }
  async get() {
    const docs = [...this.db.docs.entries()].filter(([key, data]) => key.startsWith(`${this.name}/`) &&
      this.filters.every(([field, op, value]) => op === "in" ? value.includes(data[field]) : data[field] === value))
      .slice(0, this.max).map(([key]) => this.db.snapshot(new Ref(this.db, key)));
    return { docs, empty: docs.length === 0, size: docs.length };
  }
}
class Ref {
  constructor(db, name) { this.db = db; this.path = name; this.id = name.split("/").at(-1); }
  get() { return Promise.resolve(this.db.snapshot(this)); }
  set(data, opts) { this.db.apply("set", this, data, opts); return Promise.resolve(); }
  update(data) { this.db.apply("update", this, data); return Promise.resolve(); }
  create(data) { this.db.apply("create", this, data); return Promise.resolve(); }
  delete() { this.db.apply("delete", this); return Promise.resolve(); }
}

function harness(seed = {}, options = {}) {
  const db = new FakeFirestore(seed);
  const firestore = () => db;
  firestore.Timestamp = { fromMillis: stamp, fromDate: d => stamp(d.getTime()) };
  firestore.FieldValue = { serverTimestamp: () => stamp(Date.now()), delete: () => DELETE };
  const calls = { requests: 0, sends: 0 };
  const auth = {
    verifyIdToken: async () => ({ uid: "alice", email: "alice@example.test", auth_time: Date.now() / 1000 }),
    getUser: async uid => ({ uid, email: `${uid}@example.test` }),
    deleteUser: async uid => { calls.deletedUser = uid; },
  };
  const admin = { firestore, auth: () => auth, initializeApp() {} };
  const cache = new Map();
  const appStore = {
    Environment: { PRODUCTION: "Production", SANDBOX: "Sandbox" },
    NotificationTypeV2: Object.fromEntries(["EXPIRED", "GRACE_PERIOD_EXPIRED", "REFUND", "REVOKE", "SUBSCRIBED", "DID_RENEW", "TEST"].map(x => [x, x])),
    VerificationException: class VerificationException extends Error {},
    APIException: class APIException extends Error {}, APIError: {},
    SignedDataVerifier: class {
      async verifyAndDecodeTransaction(value) { return options.transactions?.[value] || JSON.parse(value); }
      async verifyAndDecodeNotification(value) { return JSON.parse(value); }
      async verifyAndDecodeRenewalInfo(value) { return JSON.parse(value); }
    },
  };
  const overrides = {
    "firebase-admin": admin,
    "google-auth-library": { GoogleAuth: class { async getClient() { return { request: async () => {
      calls.requests++;
      if (options.playError) throw options.playError;
      return { data: options.playResponse };
    } }; } } },
    "firebase-functions/v2/https": { onRequest: (_opts, fn) => fn },
    "firebase-functions/v2/pubsub": { onMessagePublished: (opts, fn) => { calls.pubsubOptions = opts; return fn; } },
    "firebase-functions/v2/scheduler": { onSchedule: (_opts, fn) => fn },
    "firebase-functions/params": { defineString: (_name, opts) => ({ value: () => opts?.default || "" }) },
    "@apple/app-store-server-library": appStore,
  };
  function load(file) {
    const full = path.resolve(ROOT, file.endsWith(".js") ? file : `${file}.js`);
    if (cache.has(full)) return cache.get(full).exports;
    const module = { exports: {} }; cache.set(full, module);
    const sandbox = {
      module, exports: module.exports, __dirname: path.dirname(full), Buffer, Date, Set, Map, URL, AbortSignal,
      process: { env: options.env || {} }, console: { log() {}, warn() {}, error() {} },
      fetch: async () => { calls.sends++; return options.fetchResponse || { ok: true }; },
      require(name) {
        if (overrides[name]) return overrides[name];
        if (name === "./alerts") return { sendEmail: async () => {}, escapeHtml: x => x, emailEnabled: () => false };
        if (name.startsWith(".")) return load(path.relative(ROOT, path.resolve(path.dirname(full), name)));
        return require(name);
      },
    };
    vm.runInNewContext(fs.readFileSync(full, "utf8"), sandbox, { filename: full });
    return module.exports;
  }
  return { db, load, calls, auth };
}

const user = () => ({ nome: "Alice", email: "alice@example.test", is_premium: false });
const response = () => ({
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  lineItems: [{ productId: "pago_premium_monthly", expiryTime: new Date(future()).toISOString() }],
  latestOrderId: "GPA.1234", externalAccountIdentifiers: { obfuscatedExternalAccountId: "alice" },
});
const req = body => ({ method: "POST", body, get: () => "Bearer mock" });
const res = () => ({ status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } });
const notification = () => ({ data: { message: { json: { packageName: "app.usepago", subscriptionNotification: { notificationType: 2, purchaseToken: "valid" } } } } });

test("Play rejects a different product and ignores its later expiry", () => {
  const play = harness().load("play");
  const wrong = play.summarize({ ...response(), lineItems: [{ productId: "another", expiryTime: new Date(future()).toISOString() }] });
  assert.equal(play.isActive(wrong), false);
  const rightExpiry = Date.now() + 100000;
  const mixed = play.summarize({ ...response(), lineItems: [
    { productId: "pago_premium_monthly", expiryTime: new Date(rightExpiry).toISOString() },
    { productId: "another", expiryTime: new Date(future()).toISOString() },
  ] });
  assert.equal(mixed.expiry, rightExpiry);
});

for (const [code, expected] of [[503, 503], [403, 503], [404, 402], [400, 402]]) {
  test(`Play API failure ${code} grants nothing and returns ${expected}`, async () => {
    const h = harness({ "Users/alice": user() }, { playError: Object.assign(new Error("mock failure"), { code }) });
    const result = res();
    await h.load("index").confirmPlayPurchase(req({ purchaseToken: "arbitrary" }), result);
    assert.equal(result.code, expected);
    assert.equal(h.db.docs.get("Users/alice").is_premium, false);
    assert.equal(h.db.writes.length, 0);
  });
}

test("Play confirmation binds a verified subscription and grants its exact expiry", async () => {
  const data = response();
  const h = harness({ "Users/alice": user() }, { playResponse: data });
  const result = res();
  await h.load("index").confirmPlayPurchase(req({ purchaseToken: "valid" }), result);
  assert.equal(result.code, 200);
  const profile = h.db.docs.get("Users/alice");
  assert.equal(profile.is_premium, true);
  assert.equal(profile.premium_vence_em.toMillis(), Date.parse(data.lineItems[0].expiryTime));
  assert.match(profile.premium_transaction_id, /^play_/);
});

test("token ownership is checked inside the transaction even without Google account id", async () => {
  const crypto = require("node:crypto");
  const key = crypto.createHash("sha256").update("valid").digest("hex").slice(0, 40);
  const h = harness({ "Users/alice": user(), [`PlaySubscriptions/${key}`]: { uid: "bob" } });
  const summary = h.load("play").summarize({ ...response(), externalAccountIdentifiers: {} });
  await assert.rejects(h.load("play").applySubscription("alice", "valid", summary), { status: 403 });
  assert.equal(h.db.writes.length, 0);
});

test("first claim without a store account id is refused; an existing same-account link remains restorable", async () => {
  const crypto = require("node:crypto");
  const key = crypto.createHash("sha256").update("valid").digest("hex").slice(0, 40);
  const h = harness({ "Users/alice": user() });
  const play = h.load("play");
  const summary = play.summarize({ ...response(), externalAccountIdentifiers: {} });
  await assert.rejects(play.applySubscription("alice", "valid", summary), { status: 403 });
  h.db.docs.set(`PlaySubscriptions/${key}`, { uid: "alice" });
  assert.equal(await play.applySubscription("alice", "valid", summary), true);
});

test("replaced Play token cannot become an entitlement again after replacement expiry", async () => {
  const crypto = require("node:crypto");
  const oldKey = crypto.createHash("sha256").update("old").digest("hex").slice(0, 40);
  const h = harness({
    "Users/alice": user(),
    [`PlaySubscriptions/${oldKey}`]: { uid: "alice", verificada: true, estado: "SUBSCRIPTION_STATE_ACTIVE", venceEm: stamp(future()) },
  });
  const play = h.load("play");
  const summary = { ...play.summarize(response()), linkedPurchaseToken: "old" };
  await play.applySubscription("alice", "new", summary);
  assert.ok(h.db.docs.get(`PlaySubscriptions/${oldKey}`).replacedBy);
  await play.applySubscription("alice", "new", { ...summary, state: "SUBSCRIPTION_STATE_EXPIRED" });
  assert.equal(h.db.docs.get("Users/alice").is_premium, false);
});

test("deleted or missing account is never recreated by a valid Play event", async () => {
  for (const seed of [{}, { "Users/alice": user(), "DeletedAccounts/alice": { deletedAt: stamp(Date.now()) } }]) {
    const h = harness(seed, { playResponse: response() });
    await h.load("index").playNotifications(notification());
    assert.equal(h.db.writes.length, 0);
  }
});

test("transient RTDN failure rejects and enables platform retry", async () => {
  const h = harness({}, { playError: { code: 503 } });
  const index = h.load("index");
  assert.equal(h.calls.pubsubOptions.retry, true);
  await assert.rejects(index.playNotifications(notification()), /retentar/);
});

test("permanent missing RTDN token is acknowledged without granting access", async () => {
  const h = harness({}, { playError: { code: 404 } });
  await h.load("index").playNotifications(notification());
  assert.equal(h.db.writes.length, 0);
});

test("store expiration preserves a valid courtesy grant", async () => {
  const expiry = future();
  const profile = { ...user(), is_premium: true, premium_vence_em: stamp(expiry), premium_transaction_id: "admin_90d_123" };
  const h = harness({ "Users/alice": profile });
  const play = h.load("play");
  await play.applySubscription("alice", "old", { ...play.summarize(response()), state: "SUBSCRIPTION_STATE_EXPIRED" });
  assert.equal(h.db.docs.get("Users/alice").premium_transaction_id, "admin_90d_123");
  assert.equal(h.db.docs.get("Users/alice").premium_vence_em.toMillis(), expiry);
});

test("store expiration falls back to another verified active store source", async () => {
  const expiry = future();
  const h = harness({
    "Users/alice": { ...user(), is_premium: true, premium_transaction_id: "GPA.1234", premium_vence_em: stamp(expiry) },
    "AppleSubscriptions/123": { uid: "alice", verificada: true, estado: "ATIVA", venceEm: stamp(expiry), revogada: false },
  });
  const play = h.load("play");
  await play.applySubscription("alice", "old", { ...play.summarize(response()), state: "SUBSCRIPTION_STATE_EXPIRED" });
  assert.equal(h.db.docs.get("Users/alice").premium_transaction_id, "apple_123");
  assert.equal(h.db.docs.get("Users/alice").is_premium, true);
});

test("deletion writes a tombstone and clears operational tokens and follow-ups", async () => {
  const h = harness({
    "Users/alice": user(), "Debts/d1": { user_id: "alice" },
    "CollectionFollowUps/f1": { user_id: "alice" }, "MmpOutbox/m1": { uid: "alice" },
    "PlaySubscriptions/p1": { uid: "alice", purchaseToken: "private-token", verificada: true },
    "AppleSubscriptions/a1": { uid: "alice", appAccountToken: "account-token", verificada: true },
  });
  await h.load("admin").deleteOwnAccount({ uid: "alice" });
  assert.equal(h.db.writes[0].path, "DeletedAccounts/alice");
  assert.equal(h.db.docs.has("Users/alice"), false);
  assert.equal(h.db.docs.has("CollectionFollowUps/f1"), false);
  assert.equal(h.db.docs.has("MmpOutbox/m1"), false);
  assert.equal(h.db.docs.get("PlaySubscriptions/p1").purchaseToken, undefined);
  assert.equal(h.db.docs.get("AppleSubscriptions/a1").appAccountToken, undefined);
  assert.equal(h.db.docs.get("PlaySubscriptions/p1").deletedAccount, true);
  assert.equal(h.calls.deletedUser, "alice");
});

test("unexpected authentication lookup failure stops deletion before data is removed", async () => {
  const h = harness({ "Users/alice": user() });
  h.auth.getUser = async () => { throw Object.assign(new Error("unavailable"), { code: "auth/internal-error" }); };
  await assert.rejects(h.load("admin").deleteOwnAccount({ uid: "alice" }), /unavailable/);
  assert.equal(h.db.docs.has("Users/alice"), true);
  assert.equal(h.db.writes.length, 0);
});

const appleTransaction = () => ({
  productId: "pago_premium_monthly_ios", originalTransactionId: "123", transactionId: "123",
  expiresDate: future(), signedDate: Date.now(), environment: "Production", price: 39900,
});

test("Apple confirmation refuses an unbound transaction without appAccountToken", async () => {
  const h = harness({ "Users/alice": user() });
  await assert.rejects(h.load("apple").confirmPurchase("alice", { signedTransaction: JSON.stringify(appleTransaction()) }), { status: 403 });
  assert.equal(h.db.writes.length, 0);
});

test("Apple notification cannot recreate an excluded account", async () => {
  const tx = appleTransaction();
  const h = harness({ "AppleSubscriptions/123": { uid: "alice", deletedAccount: true } });
  const result = await h.load("apple").handleNotification(JSON.stringify({
    notificationType: "DID_RENEW", signedDate: Date.now(), data: { signedTransactionInfo: JSON.stringify(tx) },
  }));
  assert.equal(result.ignored, true);
  assert.equal(h.db.writes.length, 0);
});

test("Apple old period revocation cannot remove a newer renewal", async () => {
  const tx = appleTransaction();
  const expiry = tx.expiresDate + 86400000;
  const h = harness({
    "Users/alice": { ...user(), is_premium: true, premium_transaction_id: "apple_123", premium_vence_em: stamp(expiry) },
    "AppleSubscriptions/123": { uid: "alice", verificada: true, estado: "ATIVA", venceEm: stamp(expiry), eventoEm: Date.now() + 1000 },
  });
  const result = await h.load("apple").handleNotification(JSON.stringify({
    notificationType: "REFUND", signedDate: Date.now(), data: { signedTransactionInfo: JSON.stringify({ ...tx, revocationDate: Date.now() }) },
  }));
  assert.equal(result.ignored, true);
  assert.equal(h.db.docs.get("Users/alice").is_premium, true);
  assert.equal(h.db.writes.length, 0);
});

test("MMP delivery failure remains queued and is not counted as a new business event", async () => {
  const h = harness({ "Users/alice": user(), "MmpIds/alice": { android: { appsflyerId: "device-123" } } }, {
    env: { MMP_S2S_URL: "https://example.test/{app_id}", MMP_S2S_TOKEN: "test-only" },
    fetchResponse: { ok: false, status: 503, text: async () => "unavailable" },
  });
  const mmp = h.load("mmp_s2s");
  const ref = h.db.collection("PlayEvents").doc("GPA.1234");
  const event = { uid: "alice", platform: "android", transactionId: "GPA.1234", type: "COMPRA", revenue: 33.92 };
  assert.equal(await mmp.recordRevenueEvent(ref, { uid: "alice", tipo: "COMPRA" }, event), true);
  await mmp.flushRevenueEvent(event);
  const queue = [...h.db.docs.entries()].find(([key]) => key.startsWith("MmpOutbox/"))[1];
  assert.equal(queue.state, "pending");
  assert.equal(queue.lastReason, "http_503");
  assert.equal(queue.attempts, 1);
  assert.equal(await mmp.recordRevenueEvent(ref, { uid: "alice" }, event), false);
  assert.equal(h.calls.sends, 1);
});

test("MMP does not store or send events for test purchases", async () => {
  const h = harness({ "Users/alice": user() }, { env: { MMP_S2S_URL: "https://example.test", MMP_S2S_TOKEN: "test-only" } });
  const mmp = h.load("mmp_s2s");
  const event = { uid: "alice", platform: "android", transactionId: "GPA.test", type: "COMPRA", revenue: 0, test: true };
  await mmp.recordRevenueEvent(h.db.collection("PlayEvents").doc("GPA.test"), { uid: "alice" }, event);
  assert.equal([...h.db.docs.keys()].some(x => x.startsWith("MmpOutbox/")), false);
  assert.equal(h.calls.sends, 0);
});

test("a failed MMP delivery can resume without duplicating the business event", async () => {
  const options = {
    env: { MMP_S2S_URL: "https://example.test", MMP_S2S_TOKEN: "test-only" },
    fetchResponse: { ok: false, status: 503, text: async () => "unavailable" },
  };
  const h = harness({ "Users/alice": user(), "MmpIds/alice": { android: { appsflyerId: "device-123" } } }, options);
  const mmp = h.load("mmp_s2s");
  const event = { uid: "alice", platform: "android", transactionId: "GPA.retry", type: "COMPRA", revenue: 33.92 };
  await mmp.recordRevenueEvent(h.db.collection("PlayEvents").doc("GPA.retry"), { uid: "alice" }, event);
  await mmp.flushRevenueEvent(event);
  const [key, queued] = [...h.db.docs.entries()].find(([key]) => key.startsWith("MmpOutbox/"));
  h.db.docs.set(key, { ...queued, nextAttemptAt: stamp(0) });
  options.fetchResponse = { ok: true };
  await mmp.flushRevenueOutbox();
  assert.equal(h.db.docs.get(key).state, "sent");
  assert.equal(h.db.docs.get(key).attempts, 2);
  assert.equal([...h.db.docs.keys()].filter(key => key.startsWith("PlayEvents/")).length, 1);
  assert.equal(h.calls.sends, 2);
});

test("deleted account cannot regain attribution identifiers", async () => {
  const h = harness({ "Users/alice": user(), "DeletedAccounts/alice": { deletedAt: stamp(Date.now()) } });
  await h.load("mmp_s2s").rememberDevice("alice", "android", "device-123");
  assert.equal(h.db.docs.has("MmpIds/alice"), false);
});

test("admin separa receita da Google Play e da App Store", () => {
  const h = harness({});
  const { summarizeRevenue, platformCounts, originCounts } = h.load("admin")._test;
  const at = Date.UTC(2026, 9, 20, 12);
  const event = (loja, tipo, valor, em, extra = {}) => ({
    id: `${loja}${tipo}${em}`, uid: "u", nome: "", tipo, cobranca: valor > 0, valor, teste: false, loja, em, ...extra,
  });
  const summary = summarizeRevenue([
    event("play", "COMPRA", 20, Date.UTC(2026, 9, 2)),
    event("app_store", "COMPRA", 20, Date.UTC(2026, 9, 3)),
    event("app_store", "RENOVADA", 20, Date.UTC(2026, 9, 4)),
    event("app_store", "CANCELADA", 0, Date.UTC(2026, 9, 5)),
    event("play", "COMPRA", 20, Date.UTC(2026, 9, 6), { teste: true }),
    event("play", "COMPRA", 20, Date.UTC(2026, 8, 10)),
  ], at);

  assert.equal(summary.mesAtual.bruto, 60);
  assert.equal(summary.mesAtual.porLoja.play.bruto, 20);
  assert.equal(summary.mesAtual.porLoja.app_store.bruto, 40);
  assert.equal(summary.mesAtual.porLoja.app_store.liquido, 34);
  assert.equal(summary.mesAtual.liquido, 51);
  assert.equal(summary.mesAtual.novas, 2);
  assert.equal(summary.mesAtual.cancelamentos, 1);
  assert.equal(summary.mesAnterior.bruto, 20);
  assert.equal(summary.meses.length, 6);
  assert.equal(summary.meses.at(-1).app_store, 40);

  const plain = (value) => JSON.parse(JSON.stringify(value));
  assert.deepEqual(
    plain(platformCounts([{ plataforma: "android" }, { plataforma: "iOS" }, { plataforma: "iOS" }, { plataforma: "web" }, {}])),
    { android: 1, ios: 2, web: 1, outras: 0, semDado: 1 },
  );
  assert.deepEqual(plain(originCounts([{ premiumOrigem: "apple" }, { premiumOrigem: "play" }, { premiumOrigem: "" }])), {
    play: 2, apple: 1, pix: 0, admin: 0,
  });
});

const adminReq = (method, route, body = {}) => ({ method, path: route, query: {}, body, get: () => "Bearer mock" });

test("painel admin exige o segundo fator quando ADMIN_REQUIRE_2FA está ligado", async () => {
  const h = harness({ "Users/alice": user() }, { env: { ADMIN_EMAILS: "alice@example.test", ADMIN_REQUIRE_2FA: "true" } });
  const api = h.load("admin").adminApi;

  for (const [method, route] of [["GET", "/overview"], ["GET", "/log"], ["POST", "/premium"], ["POST", "/delete"]]) {
    const out = res();
    await api(adminReq(method, route, { uid: "bob", days: 30 }), out);
    assert.equal(out.code, 403, route);
    assert.equal(out.body.precisa2faSetup, true, route);
  }

  const status = res();
  await api(adminReq("GET", "/2fa/status"), status);
  assert.equal(status.code, 200);
  assert.equal(status.body.ativo, false);
  assert.equal(status.body.obrigatorio, true);

  const setup = res();
  await api(adminReq("POST", "/2fa/setup"), setup);
  assert.equal(setup.code, 200);
  assert.ok(setup.body.secret);
});

test("por padrão o painel admin não exige o segundo fator", async () => {
  const h = harness({ "Users/alice": user() }, { env: { ADMIN_EMAILS: "alice@example.test" } });
  const api = h.load("admin").adminApi;
  const status = res();
  await api(adminReq("GET", "/2fa/status"), status);
  assert.equal(status.code, 200);
  assert.equal(status.body.ativo, false);
  assert.equal(status.body.obrigatorio, false);
  const out = res();
  await api(adminReq("GET", "/log"), out);
  assert.notEqual(out.code, 403);
});

test("com o segundo fator obrigatório ele não pode ser desligado", async () => {
  const h = harness({ "Users/alice": user() }, { env: { ADMIN_EMAILS: "alice@example.test", ADMIN_REQUIRE_2FA: "true" } });
  const out = res();
  await h.load("admin").adminApi(adminReq("POST", "/2fa/disable", { code: "123456" }), out);
  assert.notEqual(out.code, 200);
});
