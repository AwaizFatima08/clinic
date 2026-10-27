import { test } from 'node:test';
import assert from 'node:assert/strict';
import { openDb } from '../src/db.js';
import { Clinic, ConflictError, NotFoundError } from '../src/clinic.js';
import { ValidationError, buildSlots, freeSlots, parseIntervals } from '../src/slots.js';

// Wed 4 Nov 2026, 09:00 in Asia/Karachi (UTC+5) = 04:00 UTC.
const WED_0900 = new Date('2026-11-04T04:00:00Z');

function makeClinic(at = WED_0900) {
  const clock = { at };
  const clinic = new Clinic(openDb(':memory:'), { now: () => clock.at });
  return { clinic, clock };
}

const patient = (over = {}) => ({ date: '2026-11-04', start: '10:00', name: 'Ayesha Khan', phone: '+92 300 1234567', ...over });

test('parseIntervals sorts ranges and rejects overlaps or bad times', () => {
  assert.deepEqual(parseIntervals([{ start: '17:00', end: '20:00' }, { start: '10:00', end: '13:00' }]), [[600, 780], [1020, 1200]]);
  assert.deepEqual(parseIntervals([]), []);
  assert.throws(() => parseIntervals([{ start: '10:00', end: '12:00' }, { start: '11:00', end: '13:00' }]), ValidationError);
  assert.throws(() => parseIntervals([{ start: '13:00', end: '10:00' }]), ValidationError);
  assert.throws(() => parseIntervals([{ start: '9:00', end: '10:00' }]), ValidationError);
});

test('buildSlots drops a leftover shorter than one slot', () => {
  assert.deepEqual(buildSlots([[600, 700]], 30).map((s) => s.start), [600, 630, 660]);
});

test('freeSlots: an appointment booked under an older slot length blocks every overlapping slot', () => {
  const free = freeSlots({ intervals: [[600, 720]], slotMinutes: 30, taken: [{ start_min: 620, end_min: 640 }] });
  assert.deepEqual(free.map((s) => s.start), [660, 690]);
});

test('default weekly timetable gives 20-minute slots in the morning and evening', () => {
  const { clinic } = makeClinic();
  const slots = clinic.slots('2026-11-04');
  // 10–13 and 17–20 → 9 + 9 slots; it is 09:00 now and notice is 60 min, so all remain.
  assert.equal(slots.length, 18);
  assert.equal(slots[0].start, 600);
  assert.equal(slots.at(-1).end, 1200);
  assert.equal(clinic.slots('2026-11-08').length, 0, 'Sunday is closed');
});

test('changing the slot length changes the slots offered', () => {
  const { clinic } = makeClinic();
  clinic.updateSettings({ slot_minutes: 30 });
  assert.equal(clinic.slots('2026-11-05').length, 12);
  assert.throws(() => clinic.updateSettings({ slot_minutes: 3 }), ValidationError);
});

test('minimum notice and past times hide slots for patients but not for the admin', () => {
  const { clinic, clock } = makeClinic();
  clock.at = new Date('2026-11-04T05:30:00Z'); // 10:30 local
  const patientStarts = clinic.slots('2026-11-04').map((s) => s.start);
  assert.equal(patientStarts[0], 700, 'first slot at or after 11:30 is 11:40');
  const adminStarts = clinic.slots('2026-11-04', { forAdmin: true }).map((s) => s.start);
  assert.equal(adminStarts[0], 640, 'admin sees from 10:40');
  assert.deepEqual(clinic.slots('2026-11-03'), [], 'yesterday has no slots');
});

test('minimum notice spills over midnight into the next day', () => {
  const { clinic, clock } = makeClinic();
  clinic.updateSettings({ min_notice_minutes: 24 * 60 });
  clock.at = new Date('2026-11-04T07:00:00Z'); // 12:00 local
  assert.equal(clinic.slots('2026-11-05')[0].start, 720, 'Thursday before 12:00 is inside the 24h notice');
});

test('booking window limits how far ahead patients can book', () => {
  const { clinic } = makeClinic();
  clinic.updateSettings({ booking_window_days: 2 });
  assert.ok(clinic.slots('2026-11-06').length > 0);
  assert.deepEqual(clinic.slots('2026-11-07'), []);
  assert.ok(clinic.slots('2026-11-07', { forAdmin: true }).length > 0);
  assert.equal(clinic.publicDays().length, 3);
});

test('a slot can be booked only once', () => {
  const { clinic } = makeClinic();
  const a = clinic.book(patient());
  assert.match(a.ref, /^[A-Z2-9]{6}$/);
  assert.equal(a.start, '10:00');
  assert.equal(a.end, '10:20');
  assert.equal(a.phone, '+923001234567');
  assert.throws(() => clinic.book(patient({ phone: '03001112222', name: 'Bilal' })), ConflictError);
  assert.ok(!clinic.slots('2026-11-04').some((s) => s.start === 600));
});

test('a phone number can hold only one booking per day (patient side)', () => {
  const { clinic } = makeClinic();
  clinic.book(patient());
  assert.throws(() => clinic.book(patient({ start: '11:00' })), ConflictError);
  assert.doesNotThrow(() => clinic.book(patient({ start: '11:00' }), { byAdmin: true }));
});

test('booking rejects times that are not real slots and bad input', () => {
  const { clinic } = makeClinic();
  assert.throws(() => clinic.book(patient({ start: '10:05' })), ConflictError);
  assert.throws(() => clinic.book(patient({ start: '14:00' })), ConflictError);
  assert.throws(() => clinic.book(patient({ phone: 'abc' })), ValidationError);
  assert.throws(() => clinic.book(patient({ name: ' ' })), ValidationError);
  assert.throws(() => clinic.book(patient({ email: 'not-an-email' })), ValidationError);
});

test('daily override: close a day, open custom hours, revert to weekly', () => {
  const { clinic } = makeClinic();
  clinic.setDay('2026-11-05', []);
  assert.equal(clinic.slots('2026-11-05').length, 0);
  const r = clinic.setDay('2026-11-08', [{ start: '14:00', end: '15:00' }]); // open on a Sunday
  assert.equal(r.day.source, 'day');
  assert.deepEqual(clinic.slots('2026-11-08').map((s) => s.start), [840, 860, 880]);
  clinic.clearDay('2026-11-05');
  assert.equal(clinic.slots('2026-11-05').length, 18);
});

test("'daily' mode: days are closed until the admin activates them", () => {
  const { clinic } = makeClinic();
  clinic.updateSettings({ schedule_mode: 'daily' });
  assert.equal(clinic.slots('2026-11-05').length, 0);
  assert.equal(clinic.dayHours('2026-11-05').source, 'not_activated');
  clinic.setDay('2026-11-05', [{ start: '10:00', end: '11:00' }]);
  assert.equal(clinic.slots('2026-11-05').length, 3);
});

test('changing hours reports booked appointments that fall outside them', () => {
  const { clinic } = makeClinic();
  const a = clinic.book(patient({ date: '2026-11-05', start: '17:00' }));
  const r = clinic.setDay('2026-11-05', [{ start: '10:00', end: '13:00' }]);
  assert.deepEqual(r.outsideHours.map((x) => x.ref), [a.ref]);
  assert.equal(clinic.setWeekly(Array(7).fill([{ start: '09:00', end: '21:00' }])).outsideHours.length, 1, 'day override still wins');
  assert.equal(clinic.clearDay('2026-11-05').outsideHours.length, 0);
});

test('patient lookup needs the right phone; cancel frees the slot', () => {
  const { clinic } = makeClinic();
  const a = clinic.book(patient());
  assert.throws(() => clinic.lookup(a.ref, '+920000000000'), NotFoundError);
  assert.equal(clinic.lookup(a.ref.toLowerCase(), '+92 300-1234567').id, a.id);
  const c = clinic.cancelByPatient(a.ref, '+923001234567');
  assert.equal(c.status, 'cancelled');
  assert.ok(clinic.slots('2026-11-04').some((s) => s.start === 600));
  assert.throws(() => clinic.cancelByPatient(a.ref, '+923001234567'), ConflictError);
});

test('re-activating a cancelled appointment fails if its time was taken', () => {
  const { clinic } = makeClinic();
  const a = clinic.book(patient());
  clinic.setStatus(a.id, 'cancelled');
  clinic.book(patient({ phone: '+923331112222', name: 'Bilal' }));
  assert.throws(() => clinic.setStatus(a.id, 'booked'), ConflictError);
});

test('admin password and sessions', () => {
  const { clinic, clock } = makeClinic();
  assert.equal(clinic.ensureAdminPassword('secret-123'), 'secret-123');
  assert.equal(clinic.ensureAdminPassword('other'), null, 'not replaced on restart');
  assert.ok(clinic.checkPassword('secret-123'));
  assert.ok(!clinic.checkPassword('wrong'));
  const t = clinic.createSession();
  assert.ok(clinic.isValidSession(t));
  clock.at = new Date(clock.at.getTime() + 13 * 3600 * 1000);
  assert.ok(!clinic.isValidSession(t), 'expires after 12h');
  clinic.changePassword('secret-123', 'new-password');
  assert.ok(clinic.checkPassword('new-password'));
  assert.throws(() => clinic.changePassword('new-password', 'short'), ValidationError);
});
