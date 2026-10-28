// Runs against the Firestore emulator: npm run test:emulator (from functions/).
import { test, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { HookBus } from '../../src/hooks.js';
import { ClinicService, ConflictError, NotFoundError, PermissionError } from '../../src/service.js';
import { registerNotifications } from '../../src/notify.js';
import { ValidationError } from '../../src/core/slots.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run with the Firestore emulator (npm run test:emulator)');

const PROJECT = 'demo-clinic-test';
initializeApp({ projectId: PROJECT });
const db = getFirestore();

// Wed 4 Nov 2026, 09:00 in Asia/Karachi = 04:00 UTC.
const clock = { at: new Date('2026-11-04T04:00:00Z') };
let service;

async function wipe() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
}

beforeEach(async () => {
  await wipe();
  clock.at = new Date('2026-11-04T04:00:00Z');
  const hooks = new HookBus({ logger: { error: (...a) => console.error(...a) } });
  service = new ClinicService(db, { hooks, now: () => clock.at });
  registerNotifications({ db, hooks, service, siteUrl: 'https://clinic.test' });
  await service.ensureSetup();
  await service.saveSettings({ requireLogin: false, adminEmail: 'doctor@clinic.test' });
});

after(wipe);

const guest = (o = {}) => ({ date: '2026-11-04', start: '10:00', name: 'Ayesha Khan', phone: '+92 300 1234567', email: 'ayesha@example.com', ...o });
const notifications = async (filter) => (await db.collection('notifications').get()).docs.map((d) => d.data()).filter(filter);
const mails = async () => (await db.collection('mail').get()).docs.map((d) => d.data());

test('setup writes public settings and day documents for the booking window', async () => {
  const day = (await db.doc('days/2026-11-04').get()).data();
  assert.equal(day.open, true);
  assert.equal(day.slots.length, 18);
  assert.equal((await db.doc('days/2026-11-08').get()).data().open, false, 'Sunday closed');
  assert.equal((await db.doc('settings/clinic').get()).data().adminEmail, undefined, 'admin email is not public');
  assert.equal((await db.doc('settings/private').get()).data().adminEmail, 'doctor@clinic.test');
});

test('booking creates the appointment, marks the slot taken and notifies', async () => {
  const a = await service.book(guest());
  assert.match(a.ref, /^[A-Z2-9]{6}$/);
  assert.equal(a.startAt, '2026-11-04T05:00:00.000Z');
  const day = (await db.doc('days/2026-11-04').get()).data();
  assert.deepEqual(day.taken, [{ start: '10:00', end: '10:20' }]);
  const m = await mails();
  assert.ok(m.some((x) => x.to === 'ayesha@example.com' && /confirmed/i.test(x.subject)), 'patient email queued');
  assert.ok(m.some((x) => x.to === 'doctor@clinic.test' && /New booking/.test(x.subject)), 'admin email queued');
  assert.equal((await notifications((n) => n.audience === 'admin')).length, 1);
});

test('a slot cannot be booked twice, even by concurrent requests', async () => {
  const results = await Promise.allSettled([
    service.book(guest({ phone: '+923001110001', name: 'One' })),
    service.book(guest({ phone: '+923001110002', name: 'Two' })),
    service.book(guest({ phone: '+923001110003', name: 'Three' })),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.ok(results.filter((r) => r.status === 'rejected').every((r) => r.reason instanceof ConflictError));
});

test('rules: one booking per phone per day, no past or unopened slots, login when required', async () => {
  await service.book(guest());
  await assert.rejects(service.book(guest({ start: '11:00' })), ConflictError);
  await assert.rejects(service.book(guest({ start: '09:40' })), ConflictError, 'outside hours');
  await assert.rejects(service.book(guest({ date: '2026-11-08' })), ConflictError, 'Sunday');
  await assert.rejects(service.book(guest({ phone: 'x' })), ValidationError);
  await service.saveSettings({ requireLogin: true });
  await assert.rejects(service.book(guest({ start: '12:00', phone: '+923339998877' })), PermissionError);
});

test('signed-in patient: profile details are used and the upcoming limit applies', async () => {
  await service.saveSettings({ requireLogin: true, maxUpcomingPerPatient: 2 });
  await service.saveProfile('uid-1', 'sara@example.com', { name: 'Sara Ahmed', phone: '+923215550001' });
  const profile = await service.profile('uid-1');
  const a = await service.book({ date: '2026-11-04', start: '11:00', reason: 'Follow-up' }, { uid: 'uid-1', profile });
  assert.equal(a.patientName, 'Sara Ahmed');
  assert.equal(a.patientUid, 'uid-1');
  await service.book({ date: '2026-11-05', start: '11:00' }, { uid: 'uid-1', profile });
  await assert.rejects(service.book({ date: '2026-11-06', start: '11:00' }, { uid: 'uid-1', profile }), /2 upcoming/);
  const inbox = await notifications((n) => n.uid === 'uid-1');
  assert.ok(inbox.some((n) => n.kind === 'welcome'));
  assert.equal(inbox.filter((n) => n.kind === 'booked').length, 2);
});

test('cancel by patient frees the slot; admin status changes notify the patient', async () => {
  await service.saveProfile('uid-2', 'bilal@example.com', { name: 'Bilal', phone: '+923331112222' });
  const a = await service.book({ date: '2026-11-04', start: '12:00' }, { uid: 'uid-2', profile: await service.profile('uid-2') });
  await assert.rejects(service.cancelByPatient(a.ref, { uid: 'someone-else' }), NotFoundError);
  await service.cancelByPatient(a.ref, { uid: 'uid-2' });
  assert.deepEqual((await db.doc('days/2026-11-04').get()).data().taken, []);
  await service.setStatusByAdmin(a.ref, 'booked');
  await service.setStatusByAdmin(a.ref, 'completed');
  const kinds = (await notifications((n) => n.uid === 'uid-2')).map((n) => n.kind);
  for (const k of ['booked', 'cancelled', 'restored', 'completed']) assert.ok(kinds.includes(k), k);
  assert.ok((await notifications((n) => n.audience === 'admin')).some((n) => n.kind === 'admin_cancelled'));
});

test('guest booking can be looked up, cancelled and claimed by phone + reference', async () => {
  const a = await service.book(guest());
  await assert.rejects(service.findForPatient(a.ref, { phone: '+920000000000' }), NotFoundError);
  assert.equal((await service.findForPatient(a.ref.toLowerCase(), { phone: '+92 300 1234567' })).ref, a.ref);
  const claimed = await service.claim(a.ref, '+923001234567', 'uid-3');
  assert.equal(claimed.patientUid, 'uid-3');
  await assert.rejects(service.claim(a.ref, '+923001234567', 'uid-4'), ConflictError);
  await service.cancelByPatient(a.ref, { phone: '+923001234567' });
});

test('picked slots on chosen days: only those slots open', async () => {
  const r = await service.setDays(['2026-11-05', '2026-11-08'], { mode: 'slots', starts: ['09:00', '09:20', '15:00'] });
  assert.deepEqual(r.outsideHours, []);
  for (const d of ['2026-11-05', '2026-11-08']) {
    const day = (await db.doc(`days/${d}`).get()).data();
    assert.equal(day.source, 'slots');
    assert.deepEqual(day.slots.map((s) => s.start), ['09:00', '09:20', '15:00']);
  }
  await service.book(guest({ date: '2026-11-08', start: '15:00' }));
  await assert.rejects(service.book(guest({ date: '2026-11-08', start: '10:00', phone: '+923001112233' })), ConflictError);
  await service.setDays(['2026-11-05'], null);
  assert.equal((await db.doc('days/2026-11-05').get()).data().source, 'weekly');
});

test('changing hours reports and notifies appointments left outside, once', async () => {
  await service.saveProfile('uid-5', 'nida@example.com', { name: 'Nida', phone: '+923005556666' });
  const a = await service.book({ date: '2026-11-05', start: '17:00' }, { uid: 'uid-5', profile: await service.profile('uid-5') });
  const r = await service.setDays(['2026-11-05'], { mode: 'hours', intervals: [{ start: '10:00', end: '13:00' }] });
  assert.deepEqual(r.outsideHours.map((x) => x.ref), [a.ref]);
  await service.saveSettings({ minNoticeMinutes: 30 }); // reports again but must not notify twice
  assert.equal((await notifications((n) => n.kind === 'outside_hours')).length, 1);
  assert.equal((await notifications((n) => n.kind === 'admin_outside_hours')).length, 1);
});

test('reminders: day-before and hour-before, each sent once', async () => {
  const a = await service.book(guest({ date: '2026-11-06', start: '10:00' })); // booked 2 days ahead
  clock.at = new Date('2026-11-05T06:00:00Z'); // 11:00 the day before (23 h to go)
  assert.equal(await service.sweepReminders(), 1);
  assert.equal(await service.sweepReminders(), 0);
  clock.at = new Date('2026-11-06T04:30:00Z'); // 09:30 on the day
  assert.equal(await service.sweepReminders(), 1);
  const subjects = (await mails()).filter((m) => m.appointmentId === a.ref).map((m) => m.subject);
  assert.ok(subjects.some((s) => /tomorrow/.test(s)));
  assert.ok(subjects.some((s) => /starts soon/.test(s)));
});

test('daily activation mode closes days until opened', async () => {
  await service.saveSettings({ scheduleMode: 'daily' });
  assert.equal((await db.doc('days/2026-11-05').get()).data().source, 'not_activated');
  await service.setDays(['2026-11-05'], { mode: 'hours', intervals: [{ start: '10:00', end: '11:00' }] });
  assert.equal((await db.doc('days/2026-11-05').get()).data().slots.length, 3);
});
