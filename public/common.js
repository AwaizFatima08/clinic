// Shared browser helpers (no framework). Everything user-supplied is inserted with
// textContent via el(), never innerHTML.

export async function api(path, { method = 'GET', body } = {}) {
  const res = await fetch(path, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
    credentials: 'same-origin',
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error || `Request failed (${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data;
}

/** el('div', {class: 'x', onclick: fn}, 'text', childNode, ...) */
export function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else if (k === 'class') node.className = v;
    else if (v === true) node.setAttribute(k, '');
    else node.setAttribute(k, v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return node;
}

export const $ = (sel, root = document) => root.querySelector(sel);

export function time12(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  if (h === 24) return '12:00 AM';
  const suffix = h >= 12 ? 'PM' : 'AM';
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${suffix}`;
}

const DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const DOW_LONG = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function dateParts(date) {
  const d = new Date(`${date}T00:00:00Z`);
  return { dow: DOW[d.getUTCDay()], dowLong: DOW_LONG[d.getUTCDay()], day: d.getUTCDate(), mon: MON[d.getUTCMonth()], year: d.getUTCFullYear() };
}

export function dateLong(date) {
  const p = dateParts(date);
  return `${p.dowLong}, ${p.day} ${p.mon} ${p.year}`;
}

export function addDays(date, n) {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function notice(container, kind, text) {
  container.replaceChildren(text ? el('div', { class: `notice ${kind}`, role: kind === 'error' ? 'alert' : 'status' }, text) : '');
}

export const WEEKDAYS = DOW_LONG;
