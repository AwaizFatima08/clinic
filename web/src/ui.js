// Small DOM helpers. User-supplied text is always inserted as text (el()), never as HTML.
export { addDays, nowInTz, fromHHMM, toHHMM } from '../../functions/src/core/time.js';

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

/** el('div', {class: 'x', onclick: fn}, 'text', childNode, [more]) */
export function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else if (k === 'class') node.className = v;
    else if (v === true) node.setAttribute(k, '');
    else node.setAttribute(k, v);
  }
  for (const c of children.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return node;
}

export function show(node, visible = true) {
  node.classList.toggle('hidden', !visible);
}

export function notice(container, kind, text) {
  container.replaceChildren(text ? el('div', { class: `notice ${kind}`, role: kind === 'error' ? 'alert' : 'status' }, text) : '');
}

/** Disables the button while the async action runs and shows errors in `msgBox`. */
export async function busy(button, msgBox, fn) {
  if (button) button.disabled = true;
  if (msgBox) notice(msgBox, '', '');
  try {
    return await fn();
  } catch (e) {
    if (msgBox) notice(msgBox, 'error', e.message || String(e));
    else alert(e.message || String(e));
    return undefined;
  } finally {
    if (button) button.disabled = false;
  }
}

export function time12(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  if (h === 24) return '12:00 AM';
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
}

export const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function dateParts(date) {
  const d = new Date(`${date}T00:00:00Z`);
  return { dow: DOW[d.getUTCDay()], dowLong: WEEKDAYS[d.getUTCDay()], weekday: d.getUTCDay(), day: d.getUTCDate(), mon: MON[d.getUTCMonth()], year: d.getUTCFullYear() };
}

export function dateLong(date) {
  const p = dateParts(date);
  return `${p.dowLong}, ${p.day} ${p.mon} ${p.year}`;
}

export function ago(date) {
  if (!date) return '';
  const s = Math.max(0, (Date.now() - date.getTime()) / 1000);
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return date.toLocaleDateString(undefined, { day: 'numeric', month: 'short' });
}

const STATUS_LABEL = { booked: 'Booked', completed: 'Completed', no_show: 'Missed', cancelled: 'Cancelled' };
export const statusBadge = (s) => el('span', { class: `badge ${s}` }, STATUS_LABEL[s] ?? s);

const SVG_NS = 'http://www.w3.org/2000/svg';
export function bellIcon() {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('width', '22');
  svg.setAttribute('height', '22');
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', 'M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6V11a7 7 0 0 0-5.5-6.84V3.5a1.5 1.5 0 0 0-3 0v.66A7 7 0 0 0 5 11v5l-2 2v1h18v-1Z');
  path.setAttribute('fill', 'currentColor');
  svg.append(path);
  return svg;
}
