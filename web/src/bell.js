// In-app notification bell: live unread count, dropdown list, mark as read.
import { collection, doc, limit, onSnapshot, orderBy, query, where, writeBatch } from 'firebase/firestore';
import { db } from './fb.js';
import { ago, bellIcon, el } from './ui.js';

/**
 * audience 'patient' (needs uid) or 'admin'. Returns a function that stops listening.
 * onOpen(notification) is called when the user clicks an item (e.g. to jump to the appointment).
 */
export function mountBell(container, { audience, uid = null, onOpen } = {}) {
  const badge = el('span', { class: 'bell-badge hidden', 'aria-hidden': 'true' });
  const button = el('button', { type: 'button', class: 'bell', 'aria-label': 'Notifications', 'aria-expanded': 'false' }, bellIcon(), badge);
  const list = el('div', { class: 'bell-list' });
  const markAll = el('button', { type: 'button', class: 'linkish', onclick: () => markRead(items.filter((n) => !n.read)) }, 'Mark all as read');
  const panel = el('div', { class: 'bell-panel hidden', role: 'dialog', 'aria-label': 'Notifications' }, el('div', { class: 'bell-head' }, el('strong', {}, 'Notifications'), markAll), list);
  const wrap = el('div', { class: 'bell-wrap' }, button, panel);
  container.replaceChildren(wrap);

  let items = [];
  const close = () => {
    panel.classList.add('hidden');
    button.setAttribute('aria-expanded', 'false');
  };
  button.addEventListener('click', (e) => {
    e.stopPropagation();
    const open = panel.classList.toggle('hidden') === false;
    button.setAttribute('aria-expanded', String(open));
  });
  const outside = (e) => {
    if (!wrap.contains(e.target)) close();
  };
  document.addEventListener('click', outside);

  async function markRead(list) {
    if (!list.length) return;
    const batch = writeBatch(db);
    for (const n of list) batch.update(doc(db, 'notifications', n.id), { read: true });
    await batch.commit().catch(() => {});
  }

  const q =
    audience === 'admin'
      ? query(collection(db, 'notifications'), where('audience', '==', 'admin'), orderBy('createdAt', 'desc'), limit(40))
      : query(collection(db, 'notifications'), where('audience', '==', 'patient'), where('uid', '==', uid), orderBy('createdAt', 'desc'), limit(40));

  const stop = onSnapshot(
    q,
    (snap) => {
      items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      const unread = items.filter((n) => !n.read).length;
      badge.textContent = unread > 9 ? '9+' : String(unread);
      badge.classList.toggle('hidden', unread === 0);
      button.setAttribute('aria-label', unread ? `Notifications, ${unread} unread` : 'Notifications');
      markAll.classList.toggle('hidden', unread === 0);
      list.replaceChildren(
        ...(items.length
          ? items.map((n) =>
              el(
                'button',
                {
                  type: 'button',
                  class: `bell-item${n.read ? '' : ' unread'}`,
                  onclick: () => {
                    if (!n.read) markRead([n]);
                    if (onOpen) {
                      close();
                      onOpen(n);
                    }
                  },
                },
                el('div', { class: 'bell-title' }, n.title),
                el('div', { class: 'bell-body' }, n.body),
                el('div', { class: 'bell-time' }, ago(n.createdAt?.toDate?.())),
              ),
            )
          : [el('p', { class: 'muted small bell-empty' }, 'No notifications yet.')]),
      );
    },
    (err) => console.warn('notifications', err),
  );

  return () => {
    stop();
    document.removeEventListener('click', outside);
    container.replaceChildren();
  };
}
