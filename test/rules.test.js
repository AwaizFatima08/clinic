// Firestore security rules, run against the emulator: npm run test:emulator
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, setDoc, updateDoc, collection, query, where, deleteDoc } from 'firebase/firestore';

let env;
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8187').split(':');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules-test',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host, port: Number(port) },
  });
});
after(() => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'settings/clinic'), { clinicName: 'Test' });
    await setDoc(doc(db, 'settings/private'), { adminEmail: 'doc@x.test' });
    await setDoc(doc(db, 'settings/weekly'), { days: {} });
    await setDoc(doc(db, 'days/2026-11-04'), { open: true, slots: [], taken: [] });
    await setDoc(doc(db, 'dayOverrides/2026-11-04'), { mode: 'hours', intervals: [] });
    await setDoc(doc(db, 'appointments/AAAAAA'), { patientUid: 'alice', phone: '+92300', status: 'booked' });
    await setDoc(doc(db, 'appointments/BBBBBB'), { patientUid: 'bob', phone: '+92301', status: 'booked' });
    await setDoc(doc(db, 'patients/alice'), { name: 'Alice' });
    await setDoc(doc(db, 'notifications/n1'), { audience: 'patient', uid: 'alice', title: 'Hi', read: false });
    await setDoc(doc(db, 'notifications/n2'), { audience: 'admin', uid: null, title: 'New booking', read: false });
    await setDoc(doc(db, 'mail/m1'), { to: 'alice@x.test' });
  });
});

const anon = () => env.unauthenticatedContext().firestore();
const alice = () => env.authenticatedContext('alice', { email: 'alice@x.test' }).firestore();
const admin = () => env.authenticatedContext('doc', { admin: true }).firestore();

test('public: clinic settings and days are readable, nothing else', async () => {
  await assertSucceeds(getDoc(doc(anon(), 'settings/clinic')));
  await assertSucceeds(getDoc(doc(anon(), 'days/2026-11-04')));
  for (const p of ['settings/private', 'settings/weekly', 'dayOverrides/2026-11-04', 'appointments/AAAAAA', 'patients/alice', 'notifications/n1', 'mail/m1']) {
    await assertFails(getDoc(doc(anon(), p)));
  }
  await assertFails(setDoc(doc(anon(), 'days/2026-11-04'), { open: false }));
});

test('patient: own appointments, profile and notifications only', async () => {
  const db = alice();
  await assertSucceeds(getDoc(doc(db, 'appointments/AAAAAA')));
  await assertFails(getDoc(doc(db, 'appointments/BBBBBB')));
  await assertSucceeds(getDocs(query(collection(db, 'appointments'), where('patientUid', '==', 'alice'))));
  await assertFails(getDocs(collection(db, 'appointments')));
  await assertSucceeds(getDoc(doc(db, 'patients/alice')));
  await assertFails(getDoc(doc(db, 'settings/private')));
  await assertSucceeds(getDoc(doc(db, 'notifications/n1')));
  await assertFails(getDoc(doc(db, 'notifications/n2')));
});

test('patient: cannot write appointments, profiles or settings directly', async () => {
  const db = alice();
  await assertFails(setDoc(doc(db, 'appointments/CCCCCC'), { patientUid: 'alice', status: 'booked' }));
  await assertFails(updateDoc(doc(db, 'appointments/AAAAAA'), { status: 'cancelled' }));
  await assertFails(setDoc(doc(db, 'patients/alice'), { name: 'Changed' }));
  await assertFails(setDoc(doc(db, 'settings/clinic'), { clinicName: 'Hacked' }));
  await assertFails(setDoc(doc(db, 'notifications/n9'), { audience: 'patient', uid: 'alice' }));
});

test('notifications: only the read flag may change, and only to true', async () => {
  const db = alice();
  await assertSucceeds(updateDoc(doc(db, 'notifications/n1'), { read: true }));
  await assertFails(updateDoc(doc(db, 'notifications/n1'), { title: 'Edited' }));
  await assertFails(updateDoc(doc(db, 'notifications/n1'), { read: false }));
  await assertFails(deleteDoc(doc(db, 'notifications/n1')));
  await assertFails(updateDoc(doc(alice(), 'notifications/n2'), { read: true }));
  await assertSucceeds(updateDoc(doc(admin(), 'notifications/n2'), { read: true }));
});

test('admin: reads everything clinic-related but still cannot write directly', async () => {
  const db = admin();
  for (const p of ['settings/private', 'settings/weekly', 'dayOverrides/2026-11-04', 'appointments/BBBBBB', 'patients/alice']) {
    await assertSucceeds(getDoc(doc(db, p)));
  }
  await assertFails(getDoc(doc(db, 'notifications/n1')), 'patient notifications stay private');
  await assertFails(getDoc(doc(db, 'mail/m1')));
  await assertFails(setDoc(doc(db, 'settings/clinic'), { clinicName: 'x' }));
});
