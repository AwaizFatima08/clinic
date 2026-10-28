// Patient page: book a slot, manage an account, see appointments and notifications.
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { collection, doc, documentId, onSnapshot, orderBy, query, where } from 'firebase/firestore';
import { auth, call, db, friendlyError } from './fb.js';
import { mountBell } from './bell.js';
import { bookableSlots, withDefaults } from '../../functions/src/core/schedule.js';
import { $, $$, addDays, busy, dateLong, dateParts, el, fromHHMM, notice, nowInTz, show, statusBadge, time12, toHHMM } from './ui.js';

const state = {
  settings: withDefaults({}),
  user: null,
  profile: null,
  days: [],
  date: null,
  slot: null,
  view: 'book',
  appointments: [],
};
const stops = { days: null, profile: null, mine: null, bell: null };

// ---------- views ----------

function go(view, opts = {}) {
  if ((view === 'mine' || view === 'profile') && !state.user) view = 'auth';
  state.view = view;
  for (const v of $$('[data-view]')) show(v, v.dataset.view === view);
  if (view === 'auth') authTab(opts.auth ?? 'login');
  notice($('#global-msg'), '', '');
  window.scrollTo({ top: 0 });
}

function authTab(name) {
  for (const b of $$('[data-auth-tab]')) b.classList.toggle('active', b.dataset.authTab === name);
  for (const p of $$('[data-auth-panel]')) show(p, p.dataset.authPanel === name);
}

for (const b of $$('[data-go]')) b.addEventListener('click', () => go(b.dataset.go, { auth: b.dataset.auth }));
for (const b of $$('[data-auth-tab]')) b.addEventListener('click', () => authTab(b.dataset.authTab));

// ---------- clinic settings & days ----------

onSnapshot(doc(db, 'settings', 'clinic'), (snap) => {
  const prev = state.settings;
  state.settings = withDefaults(snap.data());
  const s = state.settings;
  document.title = `Book an Appointment · ${s.clinicName}`;
  $('#clinic-name').textContent = s.clinicName;
  $('#doctor-name').textContent = s.doctorName;
  $('#foot-clinic').textContent = s.clinicName;
  $('#tz-note').textContent = `All times are clinic time (${s.timezone}). Each appointment is ${s.slotMinutes} minutes.`;
  if (!stops.days || prev.timezone !== s.timezone || prev.bookingWindowDays !== s.bookingWindowDays) subscribeDays();
  else renderDays();
  renderForm();
});

function today() {
  return nowInTz(state.settings.timezone);
}

function subscribeDays() {
  stops.days?.();
  const t = today().date;
  const q = query(collection(db, 'days'), where(documentId(), '>=', t), where(documentId(), '<=', addDays(t, state.settings.bookingWindowDays)));
  stops.days = onSnapshot(
    q,
    (snap) => {
      state.days = snap.docs.map((d) => d.data());
      renderDays();
    },
    (e) => notice($('#slots-msg'), 'error', friendlyError(e)),
  );
}

const toMin = (list) => (list ?? []).map((x) => ({ start: fromHHMM(x.start), end: fromHHMM(x.end) }));

function freeSlotsFor(day) {
  if (!day?.open) return [];
  return bookableSlots({ date: day.date, slots: toMin(day.slots), taken: toMin(day.taken), now: today(), settings: state.settings }).map((x) => ({
    start: toHHMM(x.start),
    end: toHHMM(x.end),
  }));
}

function renderDays() {
  const t = today().date;
  const byDate = new Map(state.days.map((d) => [d.date, d]));
  const dates = Array.from({ length: state.settings.bookingWindowDays + 1 }, (_, i) => addDays(t, i));
  const info = dates.map((date) => {
    const day = byDate.get(date);
    return { date, open: !!day?.open, free: freeSlotsFor(day).length };
  });
  $('#days').replaceChildren(
    ...info.map((d) => {
      const p = dateParts(d.date);
      const label = !d.open ? 'Closed' : d.free === 0 ? 'Full' : `${d.free} free`;
      return el(
        'button',
        {
          type: 'button',
          class: `day${d.date === state.date ? ' selected' : ''}`,
          role: 'listitem',
          'data-date': d.date,
          disabled: d.free === 0,
          'aria-label': `${dateLong(d.date)}: ${label}`,
          onclick: () => selectDate(d.date),
        },
        el('div', { class: 'dow' }, d.date === t ? 'Today' : p.dow),
        el('div', { class: 'dnum' }, p.day),
        el('div', { class: 'dow' }, p.mon),
        el('div', { class: 'dfree' }, label),
      );
    }),
  );
  const current = info.find((d) => d.date === state.date);
  if (!current || current.free === 0) {
    const first = info.find((d) => d.free > 0);
    if (first) selectDate(first.date);
    else {
      state.date = null;
      $('#slots').replaceChildren();
      show($('#form-card'), false);
      notice($('#slots-msg'), state.days.length ? 'warn' : '', state.days.length ? 'No appointments are available at the moment. Please check again later.' : '');
    }
  } else renderSlots();
}

function selectDate(date) {
  if (state.date !== date) {
    state.date = date;
    state.slot = null;
    show($('#form-card'), false);
  }
  for (const b of $$('.day')) b.classList.toggle('selected', b.dataset.date === date);
  renderSlots();
}

function renderSlots() {
  notice($('#slots-msg'), '', '');
  const slots = freeSlotsFor(state.days.find((d) => d.date === state.date));
  if (state.slot && !slots.some((s) => s.start === state.slot.start)) {
    // Someone else just took the chosen time.
    state.slot = null;
    show($('#form-card'), false);
    notice($('#slots-msg'), 'warn', 'The time you chose was just taken. Please pick another.');
  }
  const box = $('#slots');
  if (!slots.length) return box.replaceChildren(el('p', { class: 'muted' }, 'No free times left on this day.'));
  const groups = [
    ['Morning', slots.filter((s) => s.start < '12:00')],
    ['Afternoon', slots.filter((s) => s.start >= '12:00' && s.start < '17:00')],
    ['Evening', slots.filter((s) => s.start >= '17:00')],
  ].filter(([, l]) => l.length);
  box.replaceChildren(
    el('p', { class: 'muted small' }, dateLong(state.date)),
    ...groups.map(([name, list]) =>
      el(
        'div',
        { class: 'slot-group' },
        el('h3', {}, name),
        el(
          'div',
          { class: 'slots' },
          list.map((s) =>
            el('button', { type: 'button', class: `slot${state.slot?.start === s.start ? ' selected' : ''}`, 'data-start': s.start, onclick: () => selectSlot(s) }, time12(s.start)),
          ),
        ),
      ),
    ),
  );
}

function selectSlot(slot) {
  state.slot = slot;
  for (const b of $$('.slot')) b.classList.toggle('selected', b.dataset.start === slot.start);
  $('#choice-summary').replaceChildren(el('strong', {}, dateLong(state.date)), el('div', {}, `${time12(slot.start)} – ${time12(slot.end)} (clinic time)`));
  notice($('#book-msg'), '', '');
  renderForm();
  show($('#form-card'), true);
  $('#form-card').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function renderForm() {
  const needLogin = state.settings.requireLogin && !state.user;
  show($('#login-needed'), needLogin);
  show($('#book-form'), !needLogin);
  show($('#guest-fields'), !state.user);
  $('#patient-as').textContent = state.user && state.profile ? `Booking as ${state.profile.name} (${state.profile.phone})` : '';
}

$('#book-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  if (!state.slot) return;
  if (state.user && !state.profile) return go('profile');
  busy($('#book-btn'), $('#book-msg'), async () => {
    const data = { date: state.date, start: state.slot.start, reason: $('#f-reason').value };
    if (!state.user) Object.assign(data, { name: $('#f-name').value, phone: $('#f-phone').value, email: $('#f-email').value });
    try {
      const a = await call('book', data);
      $('#book-form').reset();
      state.slot = null;
      show($('#form-card'), false);
      $('#done-ref').textContent = a.ref;
      $('#done-when').textContent = `${dateLong(a.date)}, ${time12(a.start)} – ${time12(a.end)}`;
      $('#done-instructions').textContent = state.settings.instructions;
      $('#done-note').textContent = state.user
        ? 'You can see this appointment under "My appointments". We will remind you before it starts.'
        : 'Please save your booking reference. You need it, with your phone number, to view or cancel the appointment.';
      show($('#done-mine'), !!state.user);
      go('done');
    } catch (e) {
      if (e.code === 'functions/already-exists') renderSlots();
      throw e;
    }
  });
});

// ---------- account ----------

$('#login-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  busy(ev.submitter, $('.msg', ev.target), async () => {
    try {
      await signInWithEmailAndPassword(auth, $('#li-email').value.trim(), $('#li-pw').value);
    } catch (e) {
      throw new Error(friendlyError(e));
    }
    ev.target.reset();
    go(state.slot ? 'book' : 'mine');
  });
});

$('#signup-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  busy(ev.submitter, $('.msg', ev.target), async () => {
    const name = $('#su-name').value.trim();
    const phone = $('#su-phone').value.trim();
    if (name.length < 2) throw new Error('Please enter your full name.');
    if (!/^\+?\d{7,15}$/.test(phone.replace(/[\s\-().]/g, ''))) throw new Error('Please enter a valid phone number (7–15 digits, + allowed).');
    try {
      await createUserWithEmailAndPassword(auth, $('#su-email').value.trim(), $('#su-pw').value);
    } catch (e) {
      throw new Error(friendlyError(e));
    }
    await call('saveProfile', { name, phone });
    ev.target.reset();
    go(state.slot ? 'book' : 'mine');
    notice($('#global-msg'), 'ok', 'Your account is ready.');
  });
});

$('#reset-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  busy(ev.submitter, $('.msg', ev.target), async () => {
    try {
      await sendPasswordResetEmail(auth, $('#rs-email').value.trim());
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw new Error(friendlyError(e));
    }
    notice($('.msg', ev.target), 'ok', 'If an account exists for this email, a reset link is on its way.');
  });
});

$('#profile-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  busy(ev.submitter, $('.msg', ev.target), async () => {
    await call('saveProfile', { name: $('#pf-name').value, phone: $('#pf-phone').value });
    go('book');
  });
});

$('#nav-logout').addEventListener('click', async () => {
  await signOut(auth);
  go('book');
});

onAuthStateChanged(auth, (user) => {
  state.user = user;
  state.profile = null;
  for (const k of ['profile', 'mine', 'bell']) {
    stops[k]?.();
    stops[k] = null;
  }
  show($('#nav-login'), !user);
  show($('#nav-logout'), !!user);
  show($('#nav-mine'), !!user);
  show($('#nav-lookup'), !user);
  if (user) {
    call('touch').catch(() => {});
    stops.profile = onSnapshot(doc(db, 'users', user.uid), (snap) => {
      state.profile = snap.exists() && snap.data().name ? snap.data() : null;
      renderForm();
    });
    stops.mine = onSnapshot(
      query(collection(db, 'appointments'), where('patientUid', '==', user.uid), orderBy('startAt', 'desc')),
      (snap) => {
        state.appointments = snap.docs.map((d) => d.data());
        renderMine();
      },
      (e) => notice($('#mine-msg'), 'error', friendlyError(e)),
    );
    stops.bell = mountBell($('#bell'), { audience: 'patient', uid: user.uid, onOpen: () => go('mine') });
  }
  if (!user && (state.view === 'mine' || state.view === 'profile')) go('book');
  renderForm();
});

// ---------- my appointments ----------

function appointmentCard(a, { canCancel }) {
  return el(
    'div',
    { class: 'appt' },
    el(
      'div',
      {},
      el('div', {}, statusBadge(a.status), ' ', el('strong', {}, dateLong(a.date))),
      el('div', {}, `${time12(a.start)} – ${time12(a.end)}`),
      el('div', { class: 'muted small' }, `Ref ${a.ref}${a.reason ? ` · ${a.reason}` : ''}`),
    ),
    canCancel
      ? el(
          'button',
          {
            type: 'button',
            class: 'btn small danger',
            onclick: (e) => {
              if (!confirm(`Cancel your appointment on ${dateLong(a.date)} at ${time12(a.start)}?`)) return;
              busy(e.target, $('#mine-msg'), () => call('cancelMine', { ref: a.ref }));
            },
          },
          'Cancel',
        )
      : null,
  );
}

function renderMine() {
  const now = Date.now();
  const isUpcoming = (a) => a.status === 'booked' && a.startAt?.toMillis() > now;
  const upcoming = state.appointments.filter(isUpcoming).reverse();
  const past = state.appointments.filter((a) => !isUpcoming(a));
  $('#mine-upcoming').replaceChildren(
    ...(upcoming.length ? upcoming.map((a) => appointmentCard(a, { canCancel: true })) : [el('p', { class: 'muted' }, 'No upcoming appointments.')]),
  );
  $('#mine-past').replaceChildren(...(past.length ? past.map((a) => appointmentCard(a, { canCancel: false })) : [el('p', { class: 'muted' }, 'Nothing here yet.')]));
}

$('#claim-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  busy(ev.submitter, $('#claim-msg'), async () => {
    const a = await call('claimBooking', { ref: $('#cl-ref').value, phone: $('#cl-phone').value });
    ev.target.reset();
    notice($('#claim-msg'), 'ok', `Added your appointment on ${dateLong(a.date)} at ${time12(a.start)}.`);
  });
});

// ---------- guest lookup ----------

$('#lookup-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  const ref = $('#lk-ref').value;
  const phone = $('#lk-phone').value;
  $('#lookup-result').replaceChildren();
  busy(ev.submitter, $('#lookup-msg'), async () => showLookup(await call('guestLookup', { ref, phone }), phone));
});

function showLookup(a, phone) {
  const cancel =
    a.status === 'booked'
      ? el(
          'button',
          {
            type: 'button',
            class: 'btn danger',
            onclick: (e) => {
              if (!confirm('Cancel this appointment? The time will be released for other patients.')) return;
              busy(e.target, $('#lookup-msg'), async () => {
                showLookup(await call('guestCancel', { ref: a.ref, phone }), phone);
                notice($('#lookup-msg'), 'ok', 'Your appointment has been cancelled.');
              });
            },
          },
          'Cancel appointment',
        )
      : null;
  $('#lookup-result').replaceChildren(
    el(
      'div',
      { class: 'summary' },
      el('div', {}, statusBadge(a.status), ' ', el('strong', {}, a.patientName)),
      el('div', {}, `${dateLong(a.date)}, ${time12(a.start)} – ${time12(a.end)}`),
      el('div', { class: 'muted small' }, `Reference ${a.ref}`),
    ),
    cancel,
  );
}

// Keep "Today" and minimum notice correct if the page stays open.
setInterval(() => {
  if (state.days.length) renderDays();
}, 60_000);

go('book');
