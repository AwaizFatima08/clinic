import { $, WEEKDAYS, addDays, api, dateLong, el, notice, time12 } from './common.js';

const SLOT_CHOICES = [10, 15, 20, 25, 30, 40, 45, 60, 90, 120];
let today = null;
let settings = null;

// ---------- boot & auth ----------

async function init() {
  $('#login-form').addEventListener('submit', onLogin);
  $('#logout').addEventListener('click', async () => {
    await api('/api/admin/logout', { method: 'POST', body: {} }).catch(() => {});
    location.reload();
  });
  for (const b of document.querySelectorAll('nav.tabs button')) b.addEventListener('click', () => showTab(b.dataset.tab));

  try {
    ({ today } = await api('/api/admin/me'));
  } catch {
    $('#login').classList.remove('hidden');
    $('#pw').focus();
    return;
  }
  await startApp();
}

async function onLogin(ev) {
  ev.preventDefault();
  try {
    await api('/api/admin/login', { method: 'POST', body: { password: $('#pw').value } });
    ({ today } = await api('/api/admin/me'));
    $('#login').classList.add('hidden');
    await startApp();
  } catch (e) {
    notice($('#login-msg'), 'error', e.message);
  }
}

/** Any 401 after login means the session ended: go back to the login form. */
async function call(path, opts) {
  try {
    return await api(path, opts);
  } catch (e) {
    if (e.status === 401) location.reload();
    throw e;
  }
}

async function startApp() {
  $('#app').classList.remove('hidden');
  $('#logout').classList.remove('hidden');
  settings = await call('/api/admin/settings');
  setupAppointments();
  setupCalendar();
  setupWeekly();
  setupSettings();
  await loadAppointments();
  await refreshOutsideHours();
}

function showTab(name) {
  for (const b of document.querySelectorAll('nav.tabs button')) b.classList.toggle('active', b.dataset.tab === name);
  for (const p of document.querySelectorAll('[data-panel]')) p.classList.toggle('hidden', p.dataset.panel !== name);
  if (name === 'appointments') loadAppointments();
  if (name === 'calendar') loadCalendar();
  if (name === 'weekly') loadWeekly();
  if (name === 'settings') fillSettings();
}

// ---------- warnings about bookings outside hours ----------

function showOutsideHours(list) {
  const box = $('#global-warn');
  if (!list?.length) return box.replaceChildren();
  box.replaceChildren(
    el(
      'div',
      { class: 'notice warn', role: 'status' },
      el('strong', {}, `${list.length} booked appointment${list.length > 1 ? 's are' : ' is'} outside the current opening hours.`),
      ' Contact these patients or change the hours back:',
      el('ul', {}, list.slice(0, 10).map((a) => el('li', {}, `${dateLong(a.date)} ${time12(a.start)} – ${a.patient_name} (${a.phone}, ref ${a.ref})`))),
      list.length > 10 ? el('div', {}, `…and ${list.length - 10} more.`) : null,
    ),
  );
}

async function refreshOutsideHours() {
  showOutsideHours(await call('/api/admin/outside-hours').catch(() => []));
}

// ---------- appointments ----------

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
    $('#new-card').classList.remove('hidden');
    $('#n-date').value ||= today;
    loadAdminSlots();
    $('#new-card').scrollIntoView({ behavior: 'smooth' });
  });
  $('#new-cancel').addEventListener('click', () => $('#new-card').classList.add('hidden'));
  $('#n-date').addEventListener('change', loadAdminSlots);
  $('#new-form').addEventListener('submit', onAdminBook);
}

async function loadAppointments() {
  const from = $('#ap-from').value;
  const to = $('#ap-to').value || from;
  const status = $('#ap-status').value;
  notice($('#ap-msg'), '', '');
  let rows;
  try {
    rows = await call(`/api/admin/appointments?from=${from}&to=${to}${status ? `&status=${status}` : ''}`);
  } catch (e) {
    return notice($('#ap-msg'), 'error', e.message);
  }
  const tbody = $('#ap-rows');
  if (!rows.length) {
    tbody.replaceChildren(el('tr', {}, el('td', { colspan: 7, class: 'muted' }, 'No appointments in this range.')));
    return;
  }
  tbody.replaceChildren(...rows.map(appointmentRow));
}

const STATUS_LABEL = { booked: 'Booked', completed: 'Completed', no_show: 'No-show', cancelled: 'Cancelled' };

function appointmentRow(a) {
  const setStatus = (status, question) => async () => {
    if (question && !confirm(question)) return;
    try {
      await call(`/api/admin/appointments/${a.id}`, { method: 'PATCH', body: { status } });
      await loadAppointments();
      await refreshOutsideHours();
    } catch (e) {
      notice($('#ap-msg'), 'error', e.message);
    }
  };
  const actions =
    a.status === 'booked'
      ? [
          el('button', { type: 'button', class: 'btn small secondary', onclick: setStatus('completed') }, 'Done'),
          el('button', { type: 'button', class: 'btn small secondary', onclick: setStatus('no_show') }, 'No-show'),
          el('button', { type: 'button', class: 'btn small danger', onclick: setStatus('cancelled', `Cancel ${a.patient_name}'s appointment?`) }, 'Cancel'),
        ]
      : [el('button', { type: 'button', class: 'btn small secondary', onclick: setStatus('booked') }, 'Set back to booked')];
  return el(
    'tr',
    {},
    el('td', {}, dateLong(a.date)),
    el('td', {}, `${time12(a.start)} – ${time12(a.end)}`),
    el('td', {}, el('strong', {}, a.patient_name), el('div', { class: 'muted small' }, `Ref ${a.ref}${a.booked_by === 'admin' ? ' · by clinic' : ''}`)),
    el('td', {}, a.phone, a.email ? el('div', { class: 'small' }, a.email) : null),
    el('td', { class: 'small' }, a.reason || '—'),
    el('td', {}, el('span', { class: `badge ${a.status}` }, STATUS_LABEL[a.status])),
    el('td', {}, el('div', { class: 'actions' }, actions)),
  );
}

async function loadAdminSlots() {
  const sel = $('#n-slot');
  sel.replaceChildren();
  const date = $('#n-date').value;
  if (!date) return;
  try {
    const slots = await call(`/api/admin/slots?date=${date}`);
    if (!slots.length) sel.append(el('option', { value: '' }, 'No free times on this day'));
    for (const s of slots) sel.append(el('option', { value: s.start }, `${time12(s.start)} – ${time12(s.end)}`));
  } catch (e) {
    notice($('#new-msg'), 'error', e.message);
  }
}

async function onAdminBook(ev) {
  ev.preventDefault();
  try {
    const a = await call('/api/admin/appointments', {
      method: 'POST',
      body: {
        date: $('#n-date').value,
        start: $('#n-slot').value,
        name: $('#n-name').value,
        phone: $('#n-phone').value,
        email: $('#n-email').value,
        reason: $('#n-reason').value,
      },
    });
    for (const id of ['#n-name', '#n-phone', '#n-email', '#n-reason']) $(id).value = '';
    notice($('#new-msg'), 'ok', `Booked ${a.patient_name} on ${dateLong(a.date)} at ${time12(a.start)}. Reference ${a.ref}.`);
    await loadAdminSlots();
    await loadAppointments();
  } catch (e) {
    notice($('#new-msg'), 'error', e.message);
  }
}

// ---------- range editor (shared by daily and weekly hours) ----------

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
  const node = el(
    'div',
    {},
    list,
    el('div', { class: 'actions' }, el('button', { type: 'button', class: 'btn small secondary', onclick: () => addRow(nextRange(list)) }, '+ Add time range')),
  );
  const value = () =>
    [...list.querySelectorAll('.range')].map((r) => {
      const [s, e] = r.querySelectorAll('input');
      return { start: s.value, end: e.value === '23:59' ? '24:00' : e.value };
    });
  return { node, value };
}

/** Suggests a range after the last one, e.g. 17:00–20:00 after a morning session. */
function nextRange(list) {
  const ends = [...list.querySelectorAll('.range')].map((r) => r.querySelectorAll('input')[1].value).filter(Boolean).sort();
  if (!ends.length) return { start: '09:00', end: '17:00' };
  const [h] = ends.at(-1).split(':').map(Number);
  const start = Math.min(h + 1, 22);
  return { start: `${String(start).padStart(2, '0')}:00`, end: `${String(Math.min(start + 3, 23)).padStart(2, '0')}:00` };
}

const fmtRanges = (iv) => (iv.length ? iv.map((r) => `${time12(r.start)} – ${time12(r.end)}`).join(', ') : 'Closed');

// ---------- daily hours ----------

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

async function loadCalendar() {
  $('#cal-mode-note').textContent =
    settings.schedule_mode === 'daily'
      ? 'Mode: days are closed until you activate them here. “Activate” fills in the weekly timetable, which you can then adjust.'
      : 'Mode: days follow the weekly timetable automatically. Change hours or close a single day here; “Use weekly timetable” undoes a change.';
  notice($('#cal-msg'), '', '');
  let days;
  try {
    days = await call(`/api/admin/days?from=${$('#cal-from').value}&count=14`);
  } catch (e) {
    return notice($('#cal-msg'), 'error', e.message);
  }
  $('#cal-days').replaceChildren(...days.map(calendarDay));
}

const SOURCE_LABEL = { weekly: 'Weekly timetable', day: 'Set for this day', not_activated: 'Not activated' };

function calendarDay(d) {
  const open = d.intervals.length > 0;
  const box = el('div', { class: `cal-day${open ? '' : ' closed'}` });

  const save = async (intervals) => {
    try {
      const r = await call(`/api/admin/days/${d.date}`, { method: 'PUT', body: { intervals } });
      showOutsideHours(r.outsideHours);
      box.replaceWith(calendarDay(r.day));
    } catch (e) {
      notice($('#cal-msg'), 'error', `${dateLong(d.date)}: ${e.message}`);
    }
  };
  const revert = async () => {
    const r = await call(`/api/admin/days/${d.date}`, { method: 'DELETE' });
    showOutsideHours(r.outsideHours);
    box.replaceWith(calendarDay(r.day));
  };
  const edit = (initial) => {
    const editor = rangeEditor(initial);
    box.querySelector('.cal-edit')?.remove();
    box.append(
      el(
        'div',
        { class: 'cal-edit' },
        editor.node,
        el(
          'div',
          { class: 'actions' },
          el('button', { type: 'button', class: 'btn small', onclick: () => save(editor.value()) }, 'Save hours'),
          el('button', { type: 'button', class: 'btn small secondary', onclick: (e) => e.target.closest('.cal-edit').remove() }, 'Cancel'),
        ),
      ),
    );
  };

  const buttons = [];
  if (open) {
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: () => edit(d.intervals) }, 'Edit hours'));
    buttons.push(
      el('button', {
        type: 'button',
        class: 'btn small danger',
        onclick: () => {
          const q = d.appointments ? `${d.appointments} appointment(s) are booked on this day. Close it anyway? They stay booked until you cancel them.` : 'Close this day?';
          if (confirm(q)) save([]);
        },
      }, 'Close day'),
    );
  } else {
    const prefill = d.weeklyIntervals.length ? d.weeklyIntervals : [{ start: '09:00', end: '17:00' }];
    buttons.push(el('button', { type: 'button', class: 'btn small', onclick: () => save(prefill) }, 'Activate'));
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: () => edit(prefill) }, 'Activate with custom hours'));
  }
  if (d.source === 'day' && settings.schedule_mode === 'weekly') {
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: revert }, 'Use weekly timetable'));
  }
  if (d.source === 'day' && settings.schedule_mode === 'daily' && open) {
    buttons.push(el('button', { type: 'button', class: 'btn small secondary', onclick: revert }, 'Deactivate'));
  }

  box.append(
    el(
      'div',
      { class: 'cal-head' },
      el('div', {}, el('strong', {}, dateLong(d.date)), d.date === today ? el('span', { class: 'muted' }, ' · today') : null, ' ', el('span', { class: `badge src-${d.source}` }, SOURCE_LABEL[d.source])),
      el('div', { class: 'actions' }, buttons),
    ),
    el('div', { class: 'cal-hours' }, fmtRanges(d.intervals)),
    el('div', { class: 'muted small' }, `${d.appointments} booked · ${d.free} free slot${d.free === 1 ? '' : 's'} left`),
  );
  return box;
}

// ---------- weekly timetable ----------

let weekEditors = [];

function setupWeekly() {
  $('#week-save').addEventListener('click', async () => {
    try {
      const r = await call('/api/admin/weekly', { method: 'PUT', body: weekEditors.map((e) => e.value()) });
      showOutsideHours(r.outsideHours);
      notice($('#week-msg'), 'ok', 'Weekly timetable saved.');
    } catch (e) {
      notice($('#week-msg'), 'error', e.message);
    }
  });
}

async function loadWeekly() {
  $('#week-mode-note').textContent =
    settings.schedule_mode === 'daily'
      ? 'Mode: daily activation. This timetable is only used to fill in hours when you activate a day.'
      : 'These hours repeat every week. Remove all ranges to close that weekday. Single days can be changed under “Daily hours”.';
  notice($('#week-msg'), '', '');
  const week = await call('/api/admin/weekly');
  // Show Monday first.
  const order = [1, 2, 3, 4, 5, 6, 0];
  weekEditors = week.map((iv) => rangeEditor(iv));
  $('#week-days').replaceChildren(
    ...order.map((d) => el('div', { class: 'week-day' }, el('strong', {}, WEEKDAYS[d]), weekEditors[d].node)),
  );
}

// ---------- settings ----------

function setupSettings() {
  const sel = $('#s-slot_minutes');
  sel.replaceChildren(...SLOT_CHOICES.map((m) => el('option', { value: m }, `${m} minutes`)));
  $('#settings-form').addEventListener('submit', onSaveSettings);
  $('#pw-form').addEventListener('submit', onChangePassword);
}

const SETTING_FIELDS = ['clinic_name', 'doctor_name', 'slot_minutes', 'schedule_mode', 'booking_window_days', 'min_notice_minutes', 'timezone', 'instructions'];

function fillSettings() {
  notice($('#settings-msg'), '', '');
  const sel = $('#s-slot_minutes');
  if (![...sel.options].some((o) => Number(o.value) === settings.slot_minutes)) {
    sel.append(el('option', { value: settings.slot_minutes }, `${settings.slot_minutes} minutes`));
  }
  for (const k of SETTING_FIELDS) $(`#s-${k}`).value = settings[k];
}

async function onSaveSettings(ev) {
  ev.preventDefault();
  const body = Object.fromEntries(SETTING_FIELDS.map((k) => [k, $(`#s-${k}`).value]));
  for (const k of ['slot_minutes', 'booking_window_days', 'min_notice_minutes']) body[k] = Number(body[k]);
  try {
    const r = await call('/api/admin/settings', { method: 'PUT', body });
    settings = r.settings;
    ({ today } = await call('/api/admin/me'));
    showOutsideHours(r.outsideHours);
    notice($('#settings-msg'), 'ok', 'Settings saved.');
  } catch (e) {
    notice($('#settings-msg'), 'error', e.message);
  }
}

async function onChangePassword(ev) {
  ev.preventDefault();
  try {
    await call('/api/admin/password', { method: 'POST', body: { current: $('#pw-current').value, next: $('#pw-next').value } });
    alert('Password changed. Please log in again.');
    location.reload();
  } catch (e) {
    notice($('#pw-msg'), 'error', e.message);
  }
}

init();
