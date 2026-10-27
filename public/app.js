import { $, api, dateLong, dateParts, el, notice, time12 } from './common.js';

const state = { info: null, date: null, slot: null };

async function init() {
  $('#manage-toggle').addEventListener('click', () => $('#manage').classList.toggle('hidden'));
  $('#lookup-form').addEventListener('submit', onLookup);
  $('#book-form').addEventListener('submit', onBook);
  $('#book-another').addEventListener('click', () => {
    $('#done').classList.add('hidden');
    $('#booking').classList.remove('hidden');
    loadDays();
  });

  try {
    state.info = await api('/api/public/info');
  } catch (e) {
    notice($('#slots-msg'), 'error', e.message);
    return;
  }
  document.title = `Book an Appointment · ${state.info.clinic_name}`;
  $('#clinic-name').textContent = state.info.clinic_name;
  $('#doctor-name').textContent = state.info.doctor_name;
  $('#tz-note').textContent = `All times are clinic time (${state.info.timezone}). Each appointment is ${state.info.slot_minutes} minutes.`;
  await loadDays();
}

async function loadDays() {
  state.slot = null;
  $('#form-card').classList.add('hidden');
  let days;
  try {
    days = await api('/api/public/days');
  } catch (e) {
    notice($('#slots-msg'), 'error', e.message);
    return;
  }
  const strip = $('#days');
  strip.replaceChildren(
    ...days.map((d) => {
      const p = dateParts(d.date);
      const label = !d.open ? 'Closed' : d.free === 0 ? 'Full' : `${d.free} free`;
      return el(
        'button',
        {
          type: 'button',
          class: 'day',
          role: 'listitem',
          'data-date': d.date,
          disabled: d.free === 0,
          'aria-label': `${dateLong(d.date)}: ${label}`,
          onclick: () => selectDate(d.date),
        },
        el('div', { class: 'dow' }, d.date === state.info.today ? 'Today' : p.dow),
        el('div', { class: 'dnum' }, p.day),
        el('div', { class: 'dow' }, p.mon),
        el('div', { class: 'dfree' }, label),
      );
    }),
  );
  const first = days.find((d) => d.free > 0);
  if (first) selectDate(first.date);
  else {
    $('#slots').replaceChildren();
    notice($('#slots-msg'), 'warn', 'No appointments are available at the moment. Please check again later.');
  }
}

async function selectDate(date) {
  state.date = date;
  state.slot = null;
  $('#form-card').classList.add('hidden');
  for (const b of document.querySelectorAll('.day')) b.classList.toggle('selected', b.dataset.date === date);
  notice($('#slots-msg'), '', '');
  const box = $('#slots');
  box.replaceChildren(el('p', { class: 'muted' }, 'Loading times…'));
  let slots;
  try {
    slots = await api(`/api/public/slots?date=${date}`);
  } catch (e) {
    box.replaceChildren();
    notice($('#slots-msg'), 'error', e.message);
    return;
  }
  if (state.date !== date) return; // user clicked another day meanwhile
  if (!slots.length) {
    box.replaceChildren(el('p', { class: 'muted' }, 'No free times left on this day.'));
    return;
  }
  const groups = [
    ['Morning', slots.filter((s) => s.start < '12:00')],
    ['Afternoon', slots.filter((s) => s.start >= '12:00' && s.start < '17:00')],
    ['Evening', slots.filter((s) => s.start >= '17:00')],
  ].filter(([, list]) => list.length);
  box.replaceChildren(
    el('p', { class: 'muted small' }, dateLong(date)),
    ...groups.map(([name, list]) =>
      el(
        'div',
        { class: 'slot-group' },
        el('h3', {}, name),
        el(
          'div',
          { class: 'slots' },
          list.map((s) => el('button', { type: 'button', class: 'slot', 'data-start': s.start, onclick: () => selectSlot(s) }, time12(s.start))),
        ),
      ),
    ),
  );
}

function selectSlot(slot) {
  state.slot = slot;
  for (const b of document.querySelectorAll('.slot')) b.classList.toggle('selected', b.dataset.start === slot.start);
  $('#choice-summary').replaceChildren(
    el('strong', {}, dateLong(state.date)),
    el('div', {}, `${time12(slot.start)} – ${time12(slot.end)} (clinic time)`),
  );
  notice($('#book-msg'), '', '');
  const card = $('#form-card');
  card.classList.remove('hidden');
  card.scrollIntoView({ behavior: 'smooth', block: 'start' });
  $('#f-name').focus({ preventScroll: true });
}

async function onBook(ev) {
  ev.preventDefault();
  if (!state.slot) return;
  const btn = $('#book-btn');
  btn.disabled = true;
  try {
    const a = await api('/api/public/book', {
      method: 'POST',
      body: {
        date: state.date,
        start: state.slot.start,
        name: $('#f-name').value,
        phone: $('#f-phone').value,
        email: $('#f-email').value,
        reason: $('#f-reason').value,
      },
    });
    $('#book-form').reset();
    $('#booking').classList.add('hidden');
    $('#done-ref').textContent = a.ref;
    $('#done-when').textContent = `${dateLong(a.date)}, ${time12(a.start)} – ${time12(a.end)}`;
    $('#done-instructions').textContent = state.info.instructions;
    $('#done').classList.remove('hidden');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  } catch (e) {
    notice($('#book-msg'), 'error', e.message);
    if (e.status === 409) {
      // Slot was taken: refresh the times for this day.
      const date = state.date;
      await selectDate(date);
      notice($('#slots-msg'), 'error', e.message);
    }
  } finally {
    btn.disabled = false;
  }
}

async function onLookup(ev) {
  ev.preventDefault();
  const ref = $('#lk-ref').value;
  const phone = $('#lk-phone').value;
  notice($('#lookup-msg'), '', '');
  $('#lookup-result').replaceChildren();
  try {
    showLookup(await api('/api/public/lookup', { method: 'POST', body: { ref, phone } }), phone);
  } catch (e) {
    notice($('#lookup-msg'), 'error', e.message);
  }
}

function showLookup(a, phone) {
  const statusText = { booked: 'Booked', cancelled: 'Cancelled', completed: 'Completed', no_show: 'Missed' }[a.status];
  const cancelBtn =
    a.status === 'booked'
      ? el('button', {
          type: 'button',
          class: 'btn danger',
          onclick: async () => {
            if (!confirm('Cancel this appointment? The time will be released for other patients.')) return;
            try {
              showLookup(await api('/api/public/cancel', { method: 'POST', body: { ref: a.ref, phone } }), phone);
              notice($('#lookup-msg'), 'ok', 'Your appointment has been cancelled.');
              loadDays();
            } catch (e) {
              notice($('#lookup-msg'), 'error', e.message);
            }
          },
        }, 'Cancel appointment')
      : null;
  $('#lookup-result').replaceChildren(
    el(
      'div',
      { class: 'summary' },
      el('div', {}, el('span', { class: `badge ${a.status}` }, statusText), ' ', el('strong', {}, a.patient_name)),
      el('div', {}, `${dateLong(a.date)}, ${time12(a.start)} – ${time12(a.end)}`),
      el('div', { class: 'muted small' }, `Reference ${a.ref}`),
    ),
    cancelBtn,
  );
}

init();
