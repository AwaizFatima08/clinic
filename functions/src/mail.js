// Email delivery for documents in the `mail` collection, through an SMTP mailbox
// (e.g. clinic@homilabs.org on Hostinger: smtp.hostinger.com, port 465, SSL).
// Until SMTP_PASSWORD is set to a real value, mail is marked 'skipped', not sent.
import nodemailer from 'nodemailer';

export const NOT_CONFIGURED = 'NOT_CONFIGURED';

let cached = null;

export function transport({ host, port, user, password }) {
  const key = `${host}|${port}|${user}|${password}`;
  if (cached?.key !== key) {
    cached = { key, t: nodemailer.createTransport({ host, port, secure: Number(port) === 465, auth: { user, pass: password } }) };
  }
  return cached.t;
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

/** Sends one mail document. Returns the fields to write back onto it. */
export async function deliver(mail, cfg) {
  if (!cfg.password || cfg.password === NOT_CONFIGURED || !cfg.user) {
    return { status: 'skipped', error: 'SMTP is not configured yet' };
  }
  const html = `<div style="font-family:system-ui,sans-serif;font-size:15px;line-height:1.5;color:#17252b">${escapeHtml(mail.text)
    .split('\n')
    .join('<br>')}</div>`;
  try {
    const info = await transport(cfg).sendMail({ from: cfg.from || cfg.user, to: mail.to, subject: mail.subject, text: mail.text, html });
    return { status: 'sent', messageId: info.messageId ?? null };
  } catch (e) {
    return { status: 'error', error: String(e?.message ?? e).slice(0, 500) };
  }
}
