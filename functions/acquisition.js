// Origem da instalação (utm do link da Play). Só o primeiro registro vale: a
// origem de uma conta não muda depois. Sem nome, telefone ou dado da caderneta.
const admin = require("firebase-admin");

const db = () => admin.firestore();

function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}

function clean(value) {
  const text = String(value ?? "").toLowerCase().replace(/[^a-z0-9._-]/g, "");
  return text.slice(0, 64);
}

async function registerAcquisition(uid, body, store = db()) {
  const platform = String(body.platform || "").toLowerCase();
  if (!["android", "ios"].includes(platform)) throw httpError(400, "Plataforma inválida.");
  const source = clean(body.source) || "organico";
  const record = {
    uid,
    source,
    medium: clean(body.medium) || (source === "organico" ? "organico" : "indefinido"),
    campaign: clean(body.campaign),
    content: clean(body.content),
    term: clean(body.term),
    plataforma: platform,
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
  };
  const deleted = await store.collection("DeletedAccounts").doc(uid).get();
  if (deleted.exists) throw httpError(403, "Conta excluída.");
  try {
    await store.collection("Acquisition").doc(uid).create(record);
    return { ok: true, registrado: true };
  } catch (error) {
    if (error.code === 6 || /exists/i.test(String(error.message))) return { ok: true, registrado: false };
    throw error;
  }
}

module.exports = { registerAcquisition, _test: { clean } };
