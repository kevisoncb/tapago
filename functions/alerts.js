const { defineString } = require("firebase-functions/params");

const resendKeyParam = defineString("RESEND_API_KEY", { default: "" });
const alertEmailParam = defineString("ALERT_EMAIL", { default: "kevison.brandes@outlook.com" });
const alertFromParam = defineString("ALERT_FROM", { default: "Pagô Admin <onboarding@resend.dev>" });

const PANEL_URL = "https://pago-admin.web.app";

function param(definition, name) {
  try {
    return String(definition.value() || "").trim();
  } catch (_) {
    return String(process.env[name] || "").trim();
  }
}

function resendKey() {
  const key = param(resendKeyParam, "RESEND_API_KEY");
  return key && key !== "off" ? key : "";
}

function emailEnabled() {
  return !!resendKey();
}

async function sendEmail(subject, lines) {
  const key = resendKey();
  const to = param(alertEmailParam, "ALERT_EMAIL");
  if (!key || !to) return false;
  const html = `
    <div style="font-family:Arial,sans-serif;font-size:15px;color:#111827;line-height:1.5">
      ${lines.map((line) => `<p style="margin:0 0 10px">${line}</p>`).join("")}
      <p style="margin:18px 0 0"><a href="${PANEL_URL}" style="color:#2f6bff;font-weight:bold">Abrir o painel</a></p>
    </div>`;
  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({
        from: param(alertFromParam, "ALERT_FROM"),
        to: to.split(",").map((item) => item.trim()).filter(Boolean),
        subject,
        html,
      }),
    });
    if (!response.ok) console.warn("Resend recusou o e-mail", response.status, await response.text());
    return response.ok;
  } catch (error) {
    console.warn("Falha ao enviar e-mail", error.message);
    return false;
  }
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

module.exports = { sendEmail, emailEnabled, escapeHtml };
