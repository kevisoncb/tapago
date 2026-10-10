const crypto = require("crypto");

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
const STEP_SECONDS = 30;

function newSecret() {
  return base32Encode(crypto.randomBytes(20));
}

function otpauthUri(secret, account, issuer = "Pagô Admin") {
  const label = encodeURIComponent(`${issuer}:${account}`);
  return `otpauth://totp/${label}?secret=${secret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=${STEP_SECONDS}`;
}

function verifyCode(secret, code, now = Date.now()) {
  const clean = String(code || "").replace(/\D/g, "");
  if (clean.length !== 6) return false;
  const key = base32Decode(secret);
  const counter = Math.floor(now / 1000 / STEP_SECONDS);
  for (let drift = -1; drift <= 1; drift += 1) {
    const expected = hotp(key, counter + drift);
    if (crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(clean))) return true;
  }
  return false;
}

function hotp(key, counter) {
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(BigInt(counter));
  const digest = crypto.createHmac("sha1", key).update(buffer).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const binary = (digest.readUInt32BE(offset) & 0x7fffffff) % 1000000;
  return String(binary).padStart(6, "0");
}

function base32Encode(bytes) {
  let bits = 0;
  let value = 0;
  let out = "";
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

function base32Decode(text) {
  let bits = 0;
  let value = 0;
  const out = [];
  for (const char of String(text).toUpperCase().replace(/[^A-Z2-7]/g, "")) {
    value = (value << 5) | ALPHABET.indexOf(char);
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function signSession(secret, uid, ttlMs) {
  const exp = Date.now() + ttlMs;
  const payload = `${uid}.${exp}`;
  const mac = crypto.createHmac("sha256", secret).update(payload).digest("hex");
  return `${exp}.${mac}`;
}

function checkSession(secret, uid, token) {
  const [expRaw, mac] = String(token || "").split(".");
  const exp = Number(expRaw);
  if (!exp || !mac || exp < Date.now()) return false;
  const expected = crypto.createHmac("sha256", secret).update(`${uid}.${exp}`).digest("hex");
  if (expected.length !== mac.length) return false;
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(mac));
}

module.exports = { newSecret, otpauthUri, verifyCode, hotp, base32Decode, signSession, checkSession };
