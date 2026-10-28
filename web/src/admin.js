// Admin panel: appointments, opening hours (daily, picked slots, weekly), users, settings.
import { onAuthStateChanged, sendPasswordResetEmail, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { collection, doc, documentId, getDoc, getDocs, limit, onSnapshot, orderBy, query, where } from 'firebase/firestore';
import { auth, call, db, friendlyError } from './fb.js';
import { mountBell } from './bell.js';
import { bookableSlots, withDefaults } from '../../functions/src/core/schedule.js';
import { $, $$, WEEKDAYS, addDays, busy, dateLong, dateParts, el, fromHHMM, notice, nowInTz, show, statusBadge, time12, toHHMM } from './ui.js';

const SLOT_CHOICES = [10, 15, 20, 25, 30, 40, 45, 60, 90, 120];
let settings = withDefaults({});
let weekly = {};
let today = null;
const stops = [];
let started = false;

const toMin = (list) => (list ?? []).map((x) => ({ start: fromHHMM(x.start), end: fromHHMM(x.end) }));

// ---------- login & admin check ----------

$('#login-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  busy(ev.submitter, $('#login-msg'), async () => {
    try {
      await signInWithEmailAndPassword(auth, $('#email').value.trim(), $('#pw').value);
    } catch (e) {
      throw new Error(friendlyError(e));
    }
  });
});

$('#forgot').addEventListener('click', () =>
  busy(null, $('#login-msg'), async () => {
    const email = $('#email').value.trim();
    if (!email) throw new Error('Enter your email above first.');
    await sendPasswordResetEmail(auth, email).catch(() => {});
    notice($('#login-msg'), 'ok', 'If this account exists, a reset link is on its way.');
  }),
);

$('#logout').addEventListener('click', async () => {
  await signOut(auth);
  location.reload();
});
$('#retry-admin').addEventListener('click', async () => {
  await auth.currentUser?.reload();
  checkAdmin(auth.currentUser);
});
onAuthStateChanged(auth, (user) => {
  show($('#logout'), !!user);
  if (!user) {
    show($('#login'), true);
    show($('#not-admin'), false);
    show($('#app'), false);
    return;
  }
  show($('#login'), false);
  checkAdmin(user);
});

/** Admin access comes from users/{uid}.role; the email list can grant it the first time. */
async function checkAdmin(user) {
  try {
    let { role } = await call('touch');
    if (role !== 'admin') ({ role } = await call('claimAdmin'));
    if (role !== 'admin') throw new Error('This account is not a clinic admin.');
  } catch (e) {
    show($('#not-admin'), true);
    notice($('#not-admin-msg'), 'error', e.message);
    return;
  }
  show($('#not-admin'), false);
  startApp(user);
}

// ---------- app ----------

let me = null;

function startApp(user) {
  if (started) return;
  started = true;
  me = user.uid;
  show($('#app'), true);
  stops.push(mountBell($('#bell'), { audience: 'admin', onOpen: () => showTab('appointments') }));
  stops.push(
    onSnapshot(doc(db, 'settings', 'clinic'), async (snap) => {
      const priv = await getDoc(doc(db, 'settings', 'private')).catch(() => null);
      settings = withDefaults({ ...snap.data(), ...priv?.data() });
      const first = !today;
      today = nowInTz(settings.timezone).date;
      if (first) {
        setupAppointments();
        setupCalendar();
        setupPicker();
        setupWeekly();
        setupUsers();
        setupSettings();
      }
      refreshCurrentTab();
    }),
  );
  stops.push(
    onSnapshot(doc(db, 'settings', 'weekly'), (snap) => {
      weekly = snap.data()?.days ?? {};
    }),
  );
  for (const b of $$('nav.tabs button')) b.addEventListener('click', () => showTab(b.dataset.tab));
  refreshOutsideHours();
}

let currentTab = 'appointments';
function showTab(name) {
  currentTab = name;
  for (const b of $$('nav.tabs button')) b.classList.toggle('active', b.dataset.tab === name);
  for (const p of $$('[data-panel]')) show(p, p.dataset.panel === name);
  refreshCurrentTab();
}

function refreshCurrentTab() {
  if (!today) return;
  ({ appointments: loadAppointments, calendar: loadCalendar, pick: renderPicker, weekly: loadWeekly, users: loadUsers, settings: fillSettings })[currentTab]?.();
}

// ---------- warnings ----------

function showOutsideHours(list) {
  const box = $('#global-warn');
  if (!list?.length) return box.replaceChildren();
  box.replaceChildren(
    el(
      'div',
      { class: 'notice warn', role: 'status' },
      el('strong', {}, `${list.length} booked appointment${list.length > 1 ? 's are' : ' is'} outside the current opening hours.`),
      ' The patients have been notified. Contact them, cancel, or change the hours back:',
      el('ul', {}, list.slice(0, 10).map((a) => el('li', {}, `${dateLong(a.date)} ${time12(a.start)} – ${a.patientName} (${a.phone}, ref ${a.ref})`))),
      list.length > 10 ? el('div', {}, `…and ${list.length - 10} more.`) : null,
    ),
  );
}

async function refreshOutsideHours() {
  showOutsideHours(await call('outsideHours').catch(() => []));
}

/** Runs an admin change, then shows any appointments left outside the hours. */
async function change(op, data) {
  const r = await call(op, data);
  if (r?.outsideHours) showOutsideHours(r.outsideHours);
  return r;
}

// ---------- appointments ----------

let stopAppts = null;

function setupAppointments() {
  $('#ap-from').value = today;
  $('#ap-to').value = addDays(today, 6);
  for (const id of ['#ap-from', '#ap-to', '#ap-status']) $(id).addEventListener('change', loadAppointments);
  $('#ap-today').addEventListener('click', () => {
    $('#ap-from').value = today;
    $('#ap-to').value = today;
    loadAppointments();
  });
  $('#ap-new').addEventListener('click', () => {
    show($('#new-card'), true);
    $('#n-date').value ||= today;
    loadAdminSlots();
    $('#new-card').scrollIntoView({ behavior: 'smooth' });
  });
  $('#new-cancel').addEventListener('click', () => show($('#new-card'), false));
  $('#n-date').addEventListener('change', loadAdminSlots);
  $('#new-form').addEventListener('submit', onAdminBook);
}

function loadAppointments() {
  stopAppts?.();
  const from = $('#ap-from').value || today;
  const to = $('#ap-to').value || from;
  const status = $('#ap-status').value;
  notice($('#ap-msg'), '', '');
  stopAppts = onSnapshot(
    query(collection(db, 'appointments'), where('date', '>=', from), where('date', '<=', to)),
    (snap) => {
      const rows = snap.docs
        .map((d) => d.data())
        .filter((a) => !status || a.status === status)
        .sort((a, b) => (a.date + a.start < b.date + b.start ? -1 : 1));
      $('#ap-rows').replaceChildren(
        ...(rows.length ? rows.map(appointmentRow) : [el('tr', {}, el('td', { colspan: 7, class: 'muted' }, 'No appointments in this range.'))]),
      );
    },
    (e) => notice($('#ap-msg'), 'error', friendlyError(e)),
  );
}

function appointmentRow(a) {
  const setStatus = (status, question) => (e) => {
    if (question && !confirm(question)) return;
    busy(e.target, $('#ap-msg'), async () => {
      await call('setStatus', { ref: a.ref, status });
      refreshOutsideHours();
    });
  };
  const actions =
    a.status === 'booked'
      ? [
          el('button', { type: 'button', class: 'btn small secondary', onclick: setStatus('completed') }, 'Done'),
          el('button', { type: 'button', class: 'btn small secondary', onclick: setStatus('no_show') }, 'Missed'),
          el('button', { type: 'button', class: 'btn small danger', onclick: setStatus('cancelled', `Cancel ${a.patientName}'s appointment? The patient will be notified.`) }, 'Cancel'),
        ]
      : [el('button', { type: 'button', class: 'btn small secondary', onclick: setStatus('booked') }, 'Set back to booked')];
  return el(
    'tr',
    {},
    el('td', {}, dateLong(a.date)),
    el('td', {}, `${time12(a.start)} – ${time12(a.end)}`),
    el(
      'td',
      {},
      el('strong', {}, a.patientName),
      el('div', { class: 'muted small' }, `Ref ${a.ref}${a.bookedBy === 'admin' ? ' · by clinic' : ''}${a.patientUid ? ' · account' : ''}`),
    ),
    el('td', {}, a.phone, a.email ? el('div', { class: 'small' }, a.email) : null),
    el('td', { class: 'small' }, a.reason || '—'),
    el('td', {}, statusBadge(a.status), a.cancelledBy ? el('div', { class: 'muted small' }, `by ${a.cancelledBy}`) : null),
    el('td', {}, el('div', { class: 'actions' }, actions)),
  );
}

async function loadAdminSlots() {
  const sel = $('#n-slot');
  sel.replaceChildren();
  const date = $('#n-date').value;
  if (!date) return;
  const day = (await getDoc(doc(db, 'days', date))).data();
  if (!day) {
    sel.append(el('option', { value: '' }, 'This date is not set up yet – open it under Daily hours'));
    return;
  }
  const slots = bookableSlots({ date, slots: toMin(day.slots), taken: toMin(day.taken), now: nowInTz(settings.timezone), settings, forAdmin: true });
  if (!slots.length) sel.append(el('option', { value: '' }, 'No free times on this day'));
  for (const s of slots) sel.append(el('option', { value: toHHMM(s.start) }, `${time12(toHHMM(s.start))} – ${time12(toHHMM(s.end))}`));
}

function onAdminBook(ev) {
  ev.preventDefault();
  busy(ev.submitter, $('#new-msg'), async () => {
    const a = await call('adminBook', {
      date: $('#n-date').value,
      start: $('#n-slot').value,
      name: $('#n-name').value,
      phone: $('#n-phone').value,
      email: $('#n-email').value,
      reason: $('#n-reason').value,
    });
    for (const id of ['#n-name', '#n-phone', '#n-email', '#n-reason']) $(id).value = '';
    notice($('#new-msg'), 'ok', `Booked ${a.patientName} on ${dateLong(a.date)} at ${time12(a.start)}. Reference ${a.ref} – the patient can add it to their account with this reference and phone number.`);
    await loadAdminSlots();
  });
}

// ---------- range editor (opening hours) ----------

function rangeEditor(initial) {
  const list = el('div', { class: 'ranges' });
  const addRow = (r = { start: '09:00', end: '17:00' }) => {
    const row = el(
      'div',
      { class: 'range' },
      el('input', { type: 'time', value: r.start, step: 300, 'aria-label': 'Opens at' }),
      el('span', {}, 'to'),
      el('input', { type: 'time', value: r.end === '24:00' ? '23:59' : r.end, step: 300, 'aria-label': 'Closes at' }),
      el('button', { type: 'button', class: 'btn small danger', onclick: () => row.remove() }, 'Remove'),
    );
    list.append(row);
  };
  initial.forEach(addRow);
  const node = el('div', {}, list, el('div', { class: 'actions' }, el('button', { type: 'button', class: 'btn small secondary', onclick: () => addRow(nextRange(list)) }, '+ Add time range')));
  const value = () =>
    $$('.range', list).map((r) => {
      const [s, e] = $$('input', r);
      return { start: s.value, end: e.value === '23:59' ? '24:00' : e.value };
    });
  return { node, value };
}

function nextRange(list) {
  const ends = $$('.range', list).map((r) => $$('input', r)[1].value).filter(Boolean).sort();
  if (!ends.length) return { start: '09:00', end: '17:00' };
  const start = Math.min(Number(ends.at(-1).split(':')[0]) + 1, 22);
  return { start: `${String(start).padStart(2, '0')}:00`, end: `${String(Math.min(start + 3, 23)).padStart(2, '0')}:00` };
}

const fmtRanges = (iv) => (iv?.length ? iv.map((r) => `${time12(r.start)} – ${time12(r.end)}`).join(', ') : 'Closed');

// ---------- slot picker (shared by "Pick slots" and per-day picking) ----------

/**
 * A grid of toggle buttons, one per slot start between `from` and `to`.
 * `taken` starts are marked (they stay booked whatever is picked).
 */
function slotPicker({ from = '08:00', to = '22:00', selected = [], taken = [], onChange } = {}) {
  const chosen = new Set(selected);
  const grid = el('div', { class: 'picker' });
  const len = settings.slotMinutes;
  const render = (gridFrom, gridTo) => {
    const a = fromHHMM(gridFrom) ?? 480;
    const b = fromHHMM(gridTo) ?? 1320;
    const starts = new Set([...chosen]);
    for (let t = a; t + len <= Math.min(b, 1440); t += len) starts.add(toHHMM(t));
    grid.replaceChildren(
      ...[...starts].sort().map((s) =>
        el(
          'button',
          {
            type: 'button',
            class: `pick${chosen.has(s) ? ' on' : ''}${taken.includes(s) ? ' taken' : ''}`,
            'data-start': s,
            'aria-pressed': String(chosen.has(s)),
            title: taken.includes(s) ? 'Already booked' : undefined,
            onclick: (e) => {
              if (chosen.has(s)) chosen.delete(s);
              else chosen.add(s);
              e.currentTarget.classList.toggle('on', chosen.has(s));
              e.currentTarget.setAttribute('aria-pressed', String(chosen.has(s)));
              onChange?.(chosen.size);
            },
          },
          time12(s),
        ),
      ),
    );
    onChange?.(chosen.size);
  };
  render(from, to);
  return {
    node: grid,
    value: () => [...chosen].sort(),
    setRange: render,
    selectAll: () => {
      for (const b of $$('.pick', grid)) {
        b.classList.add('on');
        b.setAttribute('aria-pressed', 'true');
        chosen.add(b.dataset.start);
      }
      onChange?.(chosen.size);
    },
    clear: () => {
      chosen.clear();
      for (const b of $$('.pick', grid)) {
        b.classList.remove('on');
        b.setAttribute('aria-pressed', 'false');
      }
      onChange?.(0);
    },
  };
}

// ---------- daily hours ----------

let stopCal = [];

function setupCalendar() {
  $('#cal-from').value = today;
  $('#cal-from').addEventListener('change', loadCalendar);
  $('#cal-prev').addEventListener('click', () => {
    $('#cal-from').value = addDays($('#cal-from').value, -14);
    loadCalendar();
  });
  $('#cal-next').addEventListener('click', () => {
    $('#cal-from').value = addDays($('#cal-from').value, 14);
    loadCalendar();
  });
}

function loadCalendar() {
  stopCal.forEach((f) => f());
  $('#cal-mode-note').textContent =
    settings.scheduleMode === 'daily'
      ? 'Mode: days are closed until you open them here (or in “Pick slots”). “Open” fills in the weekly timetable, which you can adjust.'
      : 'Mode: days follow the weekly timetable automatically. Change the hours, pick single slots or close a day here; “Use weekly timetable” undoes it.';
  const from = $('#cal-from').value || today;
  const to = addDays(from, 13);
  const dates = Array.from({ length: 14 }, (_, i) => addDays(from, i));
  let days = new Map();
  let overrides = new Map();
  const render = () => $('#cal-days').replaceChildren(...dates.map((d) => calendarDay(d, days.get(d), overrides.get(d))));
  const range = (c) => query(collection(db, c), where(documentId(), '>=', from), where(documentId(), '<=', to));
  stopCal = [
    onSnapshot(range('days'), (s) => {
      days = new Map(s.docs.map((d) => [d.id, d.data()]));
      render();
    }),
    onSnapshot(range('dayOverrides'), (s) => {
      overrides = new Map(s.docs.map((d) => [d.id, d.data()]));
      render();
    }),
  ];
}

const SOURCE_LABEL = { weekly: 'Weekly timetable', hours: 'Hours set for this day', slots: 'Picked slots', not_activated: 'Not opened' };

function calendarDay(date, day, override) {
  const weeklyHours = weekly[dateParts(date).weekday] ?? [];
  const source = day?.source ?? (settings.scheduleMode === 'daily' ? 'not_activated' : 'weekly');
  const open = !!day?.open;
  const booked = day?.taken?.length ?? 0;
  const free = day ? bookableSlots({ date, slots: toMin(day.slots), taken: toMin(day.taken), now: nowInTz(settings.timezone), settings, forAdmin: true }).length : 0;
  const box = el('div', { class: `cal-day${open ? '' : ' closed'}` });
  const msg = $('#cal-msg');

  const save = (override) => busy(null, msg, () => change('setDays', { dates: [date], override }));
  const editor = (node, onSave) => {
    $('.cal-edit', box)?.remove();
    box.append(
      el(
        'div',
        { class: 'cal-edit' },
        node,
        el(
          'div',
          { class: 'actions' },
          el('button', { type: 'button', class: 'btn small', onclick: onSave }, 'Save'),
          el('button', { type: 'button', class: 'btn small secondary', onclick: (e) => e.target.closest('.cal-edit').remove() }, 'Cancel'),
        ),
      ),
    );
  };
  const editHours = (initial) => {
    const r = rangeEditor(initial);
    editor(r.node, () => save({ mode: 'hours', intervals: r.value() }));
  };
  const pickSlots = () => {
    const selected = source === 'slots' ? override?.starts ?? [] : (day?.slots ?? []).map((s) => s.start);
    const p = slotPicker({ selected, taken: (day?.taken ?? []).map((t) => t.start) });
    editor(el('div', {}, el('p', { class: 'muted small' }, 'Tick the times to open. Only ticked slots will be bookable on this day.'), p.node), () =>
      save({ mode: 'slots', starts: p.value() }),
    );
  };

  const prefill = override?.intervals?.length ? override.intervals : weeklyHours.length ? weeklyHours : [{ start: '09:00', end: '17:00' }];
  const buttons = [];
  if (open) {
    const current = source === 'hours' ? override.intervals : source === 'weekly' ? weeklyHours : prefill;
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: () => editHours(current) }, 'Edit hours'));
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: pickSlots }, 'Pick slots'));
    buttons.push(
      el(
        'button',
        {
          type: 'button',
          class: 'btn small danger',
          onclick: () => {
            const q = booked ? `${booked} appointment(s) are booked on this day. Close it anyway? They stay booked until you cancel them, and the patients are notified.` : 'Close this day?';
            if (confirm(q)) save({ mode: 'hours', intervals: [] });
          },
        },
        'Close day',
      ),
    );
  } else {
    buttons.push(el('button', { type: 'button', class: 'btn small', onclick: () => save({ mode: 'hours', intervals: prefill }) }, 'Open'));
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: () => editHours(prefill) }, 'Open with custom hours'));
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: pickSlots }, 'Open picked slots'));
  }
  if (override) {
    buttons.push(
      el('button', { type: 'button', class: 'btn small secondary', onclick: () => save(null) }, settings.scheduleMode === 'weekly' ? 'Use weekly timetable' : 'Remove opening'),
    );
  }

  const hoursText =
    source === 'slots'
      ? (day?.slots ?? []).map((s) => time12(s.start)).join(', ') || 'No slots picked'
      : fmtRanges(source === 'hours' ? override?.intervals : source === 'weekly' ? weeklyHours : []);

  box.append(
    el(
      'div',
      { class: 'cal-head' },
      el('div', {}, el('strong', {}, dateLong(date)), date === today ? el('span', { class: 'muted' }, ' · today') : null, ' ', el('span', { class: `badge src-${source}` }, SOURCE_LABEL[source])),
      el('div', { class: 'actions' }, buttons),
    ),
    el('div', { class: 'cal-hours' }, hoursText),
    el('div', { class: 'muted small' }, `${booked} booked · ${free} free slot${free === 1 ? '' : 's'} left`),
  );
  return box;
}

// ---------- pick slots on many days ----------

let picker = null;
const pickDays = new Set([0, 1, 2, 3, 4, 5, 6]);

function setupPicker() {
  $('#pk-from').value = addDays(today, 1);
  $('#pk-to').value = addDays(today, 7);
  $('#pk-weekdays').replaceChildren(
    ...[1, 2, 3, 4, 5, 6, 0].map((d) =>
      el(
        'button',
        {
          type: 'button',
          class: 'chip on',
          'aria-pressed': 'true',
          onclick: (e) => {
            if (pickDays.has(d)) pickDays.delete(d);
            else pickDays.add(d);
            e.currentTarget.classList.toggle('on', pickDays.has(d));
            e.currentTarget.setAttribute('aria-pressed', String(pickDays.has(d)));
            updatePickDates();
          },
        },
        WEEKDAYS[d].slice(0, 3),
      ),
    ),
  );
  for (const id of ['#pk-from', '#pk-to']) $(id).addEventListener('change', updatePickDates);
  for (const id of ['#pk-grid-from', '#pk-grid-to']) $(id).addEventListener('change', () => picker?.setRange($('#pk-grid-from').value, $('#pk-grid-to').value));
  $('#pk-all').addEventListener('click', () => picker?.selectAll());
  $('#pk-none').addEventListener('click', () => picker?.clear());
  const apply = (override, question) => (e) => {
    const dates = pickDates();
    if (!dates.length) return notice($('#pk-msg'), 'error', 'Choose at least one day.');
    if (dates.length > 62) return notice($('#pk-msg'), 'error', 'Choose at most 62 days at a time.');
    const q = question?.(dates.length);
    if (q && !confirm(q)) return;
    busy(e.target, $('#pk-msg'), async () => {
      await change('setDays', { dates, override: override() });
      notice($('#pk-msg'), 'ok', `Saved for ${dates.length} day${dates.length > 1 ? 's' : ''}.`);
    });
  };
  $('#pk-apply').addEventListener(
    'click',
    apply(
      () => ({ mode: 'slots', starts: picker.value() }),
      (n) => (picker.value().length ? null : `No slots are ticked, so the ${n} day(s) will be closed. Continue?`),
    ),
  );
  $('#pk-close').addEventListener('click', apply(() => ({ mode: 'hours', intervals: [] }), (n) => `Close ${n} day(s)?`));
  $('#pk-reset').addEventListener('click', apply(() => null, (n) => `Return ${n} day(s) to the weekly timetable?`));
}

function pickDates() {
  const from = $('#pk-from').value;
  const to = $('#pk-to').value;
  if (!from || !to || to < from) return [];
  const out = [];
  for (let d = from; d <= to && out.length <= 62; d = addDays(d, 1)) if (pickDays.has(dateParts(d).weekday)) out.push(d);
  return out;
}

function updatePickDates() {
  const dates = pickDates();
  $('#pk-dates-note').textContent = dates.length
    ? `${dates.length} day${dates.length > 1 ? 's' : ''}: ${dates.slice(0, 6).map((d) => `${dateParts(d).dow} ${dateParts(d).day} ${dateParts(d).mon}`).join(', ')}${dates.length > 6 ? ', …' : ''}`
    : 'No days match.';
}

function renderPicker() {
  $('#pk-len').textContent = `(${settings.slotMinutes}-minute slots)`;
  const keep = picker?.value() ?? [];
  picker = slotPicker({
    from: $('#pk-grid-from').value,
    to: $('#pk-grid-to').value,
    selected: keep,
    onChange: (n) => ($('#pk-count').textContent = `${n} slot${n === 1 ? '' : 's'} ticked`),
  });
  $('#pk-grid').replaceWith(Object.assign(picker.node, { id: 'pk-grid' }));
  updatePickDates();
}

// ---------- weekly timetable ----------

let weekEditors = [];

function setupWeekly() {
  $('#week-save').addEventListener('click', (e) =>
    busy(e.target, $('#week-msg'), async () => {
      const days = Object.fromEntries(weekEditors.map((ed, d) => [d, ed.value()]));
      await change('saveWeekly', { days });
      notice($('#week-msg'), 'ok', 'Weekly timetable saved.');
    }),
  );
}

async function loadWeekly() {
  $('#week-mode-note').textContent =
    settings.scheduleMode === 'daily'
      ? 'Mode: daily opening. This timetable only fills in the hours when you open a day.'
      : 'These hours repeat every week. Remove all ranges to close that weekday. Single days can be changed under “Daily hours” or “Pick slots”.';
  notice($('#week-msg'), '', '');
  const snap = await getDoc(doc(db, 'settings', 'weekly'));
  const days = snap.data()?.days ?? {};
  weekEditors = Array.from({ length: 7 }, (_, d) => rangeEditor(days[d] ?? []));
  $('#week-days').replaceChildren(...[1, 2, 3, 4, 5, 6, 0].map((d) => el('div', { class: 'week-day' }, el('strong', {}, WEEKDAYS[d]), weekEditors[d].node)));
}

// ---------- users ----------

let users = [];
const ROLE_LABEL = { patient: 'Patient', admin: 'Admin' };

function setupUsers() {
  $('#pt-search').addEventListener('input', renderUsers);
  $('#pt-role').addEventListener('change', renderUsers);
}

async function loadUsers() {
  try {
    const snap = await getDocs(query(collection(db, 'users'), orderBy('createdAt', 'desc'), limit(1000)));
    users = snap.docs.map((d) => ({ uid: d.id, ...d.data() }));
    renderUsers();
  } catch (e) {
    notice($('#pt-msg'), 'error', friendlyError(e));
  }
}

function roleControl(u) {
  if (u.uid === me) return el('span', { class: 'badge booked' }, 'Admin (you)');
  const sel = el(
    'select',
    {
      'aria-label': `Role of ${u.name || u.email}`,
      onchange: async (e) => {
        const role = e.target.value;
        const who = u.name || u.email;
        const q = role === 'admin' ? `Give ${who} full admin access (appointments, hours, patients, settings)?` : `Remove admin access from ${who}?`;
        if (!confirm(q)) {
          e.target.value = u.role ?? 'patient';
          return;
        }
        e.target.disabled = true;
        await busy(null, $('#pt-msg'), async () => {
          await call('setRole', { uid: u.uid, role });
          u.role = role;
          notice($('#pt-msg'), 'ok', `${who} is now ${ROLE_LABEL[role].toLowerCase()}.`);
        });
        e.target.value = u.role ?? 'patient';
        e.target.disabled = false;
      },
    },
    Object.entries(ROLE_LABEL).map(([v, label]) => el('option', { value: v, selected: (u.role ?? 'patient') === v }, label)),
  );
  return sel;
}

function renderUsers() {
  const q = $('#pt-search').value.trim().toLowerCase();
  const role = $('#pt-role').value;
  const rows = users.filter((u) => (!role || (u.role ?? 'patient') === role) && (!q || `${u.name} ${u.phone} ${u.email}`.toLowerCase().includes(q)));
  $('#pt-rows').replaceChildren(
    ...(rows.length
      ? rows.map((u) =>
          el(
            'tr',
            {},
            el('td', {}, el('strong', {}, u.name || '—')),
            el('td', {}, u.phone || '—'),
            el('td', { class: 'small' }, u.email),
            el('td', {}, roleControl(u)),
            el('td', { class: 'small' }, u.createdAt?.toDate?.().toLocaleDateString() ?? '', u.lastLoginAt ? el('div', { class: 'muted' }, `last login ${u.lastLoginAt.toDate().toLocaleDateString()}`) : null),
            el('td', {}, el('button', { type: 'button', class: 'btn small secondary', onclick: () => showPatient(u) }, 'Appointments')),
          ),
        )
      : [el('tr', {}, el('td', { colspan: 6, class: 'muted' }, q || role ? 'No user matches.' : 'No accounts yet.'))]),
  );
}

async function showPatient(p) {
  const box = $('#pt-detail');
  show(box, true);
  box.replaceChildren(el('h2', {}, p.name || p.email), el('p', { class: 'muted' }, `${p.phone || '—'} · ${p.email}`), el('p', { class: 'muted' }, 'Loading…'));
  const snap = await getDocs(query(collection(db, 'appointments'), where('patientUid', '==', p.uid), orderBy('startAt', 'desc')));
  const list = snap.docs.map((d) => d.data());
  box.replaceChildren(
    el('h2', {}, p.name || p.email),
    el('p', { class: 'muted' }, `${p.phone || '—'} · ${p.email}`),
    list.length
      ? el(
          'div',
          { class: 'table-scroll' },
          el(
            'table',
            {},
            el('thead', {}, el('tr', {}, el('th', {}, 'Date'), el('th', {}, 'Time'), el('th', {}, 'Reason'), el('th', {}, 'Status'))),
            el('tbody', {}, list.map((a) => el('tr', {}, el('td', {}, dateLong(a.date)), el('td', {}, time12(a.start)), el('td', { class: 'small' }, a.reason || '—'), el('td', {}, statusBadge(a.status))))),
          ),
        )
      : el('p', { class: 'muted' }, 'No appointments yet.'),
  );
  box.scrollIntoView({ behavior: 'smooth' });
}

// ---------- settings ----------

const SETTING_FIELDS = ['clinicName', 'doctorName', 'slotMinutes', 'scheduleMode', 'bookingWindowDays', 'minNoticeMinutes', 'requireLogin', 'maxUpcomingPerPatient', 'emailNotifications', 'adminEmail', 'timezone', 'instructions'];
const NUMBERS = ['slotMinutes', 'bookingWindowDays', 'minNoticeMinutes', 'maxUpcomingPerPatient'];
const BOOLS = ['requireLogin', 'emailNotifications'];

function setupSettings() {
  $('#s-slotMinutes').replaceChildren(...SLOT_CHOICES.map((m) => el('option', { value: m }, `${m} minutes`)));
  $('#test-email').addEventListener('click', (e) =>
    busy(e.target, $('#mail-msg'), async () => {
      const { id, to } = await call('testEmail');
      notice($('#mail-msg'), 'ok', `Sending to ${to}…`);
      for (let i = 0; i < 15; i++) {
        await new Promise((r) => setTimeout(r, 2000));
        const r = await call('mailStatus', { id });
        if (r.status === 'sent') return notice($('#mail-msg'), 'ok', `Sent to ${to}. Check the inbox (and the spam folder).`);
        if (r.status !== 'pending') throw new Error(`Email not sent (${r.status}): ${r.error ?? 'unknown error'}`);
      }
      throw new Error('No answer from the mail function yet. Try again in a minute.');
    }),
  );
  $('#settings-form').addEventListener('submit', (ev) => {
    ev.preventDefault();
    busy(ev.submitter, $('#settings-msg'), async () => {
      const body = Object.fromEntries(SETTING_FIELDS.map((k) => [k, $(`#s-${k}`).value]));
      for (const k of NUMBERS) body[k] = Number(body[k]);
      for (const k of BOOLS) body[k] = body[k] === 'true';
      await change('saveSettings', body);
      notice($('#settings-msg'), 'ok', 'Settings saved.');
    });
  });
}

function fillSettings() {
  const sel = $('#s-slotMinutes');
  if (![...sel.options].some((o) => Number(o.value) === settings.slotMinutes)) sel.append(el('option', { value: settings.slotMinutes }, `${settings.slotMinutes} minutes`));
  for (const k of SETTING_FIELDS) $(`#s-${k}`).value = String(settings[k] ?? '');
}
