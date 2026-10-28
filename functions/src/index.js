// Cloud Functions for the clinic scheduler (region asia-south1, next to Firestore).
//   api        one callable endpoint; `op` picks the action (see OPS below)
//   sendMail   delivers documents added to `mail`
//   reminders  every 10 minutes: day-before and hour-before reminders
//   nightly    extends the public day documents as the booking window moves forward
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { onDocumentCreated } from 'firebase-functions/firestore';
import { onSchedule } from 'firebase-functions/scheduler';
import { logger } from 'firebase-functions';
import { HookBus } from './hooks.js';
import { ClinicService, ConflictError, NotFoundError, PermissionError, ValidationError } from './service.js';
import { registerNotifications } from './notify.js';
import { deliver } from './mail.js';
import { loadExtensions } from './extensions/index.js';

setGlobalOptions({ region: 'asia-south1', maxInstances: 5, memory: '256MiB' });

const ADMIN_EMAILS = defineString('ADMIN_EMAILS', { description: 'Comma-separated emails allowed to become clinic admin' });
const SITE_URL = defineString('SITE_URL', { default: 'https://clinic-schedule.homilabs.org' });
const SMTP_HOST = defineString('SMTP_HOST', { default: 'smtp.hostinger.com' });
const SMTP_PORT = defineString('SMTP_PORT', { default: '465' });
const SMTP_USER = defineString('SMTP_USER', { default: '' });
const MAIL_FROM = defineString('MAIL_FROM', { default: '' });
const SMTP_PASSWORD = defineSecret('SMTP_PASSWORD');

initializeApp();
const db = getFirestore();

let ctx = null;
/** Builds the service, hooks and extensions once per instance (params are readable only at runtime). */
function context() {
  if (ctx) return ctx;
  const hooks = new HookBus({ logger });
  const service = new ClinicService(db, { hooks });
  const { notify } = registerNotifications({ db, hooks, service, siteUrl: SITE_URL.value() });
  loadExtensions({ db, hooks, service, notify });
  const lookupEmail = (uid) => getAuth().getUser(uid).then((u) => u.email ?? null).catch(() => null);
  ctx = { hooks, service, setup: service.ensureSetup().then(() => service.migrateUsers(lookupEmail)) };
  return ctx;
}

// ---------- auth helpers ----------

/** Roles live in users/{uid}.role, so a change takes effect on the very next request. */
async function requireAuth(level, auth, service) {
  if (level === 'public') return;
  if (!auth) throw new HttpsError('unauthenticated', 'Please log in.');
  if (level === 'admin' && (await service.role(auth.uid)) !== 'admin') throw new HttpsError('permission-denied', 'Admin access only.');
}

// Best-effort per-instance limiter for the unauthenticated operations.
const hits = new Map();
function rateLimit(key, max, windowMs) {
  const now = Date.now();
  const h = hits.get(key);
  if (!h || h.until < now) hits.set(key, { n: 1, until: now + windowMs });
  else if (++h.n > max) throw new HttpsError('resource-exhausted', 'Too many attempts. Please try again later.');
  if (hits.size > 5000) hits.clear();
}

// ---------- operations ----------

const OPS = {
  // patient (signed in)
  saveProfile: ['patient', ({ service, auth, data }) => service.saveProfile(auth.uid, auth.token.email ?? '', data)],
  book: [
    'public',
    async ({ service, auth, data, ip }) => {
      if (!auth) rateLimit(`book:${ip}`, 10, 3600_000);
      const profile = auth ? await service.profile(auth.uid) : null;
      return service.book(data, { uid: auth?.uid ?? null, profile });
    },
  ],
  cancelMine: ['patient', ({ service, auth, data }) => service.cancelByPatient(data?.ref, { uid: auth.uid })],
  claimBooking: [
    'patient',
    ({ service, auth, data }) => {
      rateLimit(`claim:${auth.uid}`, 20, 900_000);
      return service.claim(data?.ref, data?.phone, auth.uid);
    },
  ],

  // guest (no account): reference + phone number
  guestLookup: [
    'public',
    ({ service, data, ip }) => {
      rateLimit(`lookup:${ip}`, 30, 900_000);
      return service.findForPatient(data?.ref, { phone: data?.phone });
    },
  ],
  guestCancel: [
    'public',
    ({ service, data, ip }) => {
      rateLimit(`lookup:${ip}`, 30, 900_000);
      return service.cancelByPatient(data?.ref, { phone: data?.phone });
    },
  ],

  // First-time admin: an account whose email is in ADMIN_EMAILS (each address can be claimed
  // once, see ClinicService.bootstrapAdmin). After that, admins manage roles in the Users tab.
  claimAdmin: ['patient', ({ service, auth }) => service.bootstrapAdmin(auth.uid, auth.token.email, ADMIN_EMAILS.value().split(','))],
  touch: [
    'patient',
    async ({ service, auth }) => {
      await service.touchLogin(auth.uid);
      return { role: await service.role(auth.uid) };
    },
  ],

  // admin
  setRole: ['admin', ({ service, auth, data }) => service.setRole(auth.uid, data?.uid, data?.role)],
  saveSettings: ['admin', ({ service, data }) => service.saveSettings(data)],
  saveWeekly: ['admin', ({ service, data }) => service.saveWeekly(data?.days)],
  setDays: ['admin', ({ service, data }) => service.setDays(data?.dates, data?.override ?? null)],
  adminBook: ['admin', ({ service, data }) => service.book(data, { byAdmin: true })],
  setStatus: ['admin', ({ service, data }) => service.setStatusByAdmin(data?.ref, data?.status)],
  outsideHours: ['admin', ({ service }) => service.outsideHours()],
  rebuildDays: ['admin', async ({ service }) => ({ days: await service.rebuildWindow() })],
  // Sends a test email to the signed-in admin; poll mailStatus for the result.
  testEmail: [
    'admin',
    async ({ service, auth }) => {
      const s = await service.settings();
      const to = auth.token.email;
      if (!to) throw new HttpsError('failed-precondition', 'Your account has no email address.');
      const ref = await db.collection('mail').add({
        to,
        subject: `Test email – ${s.clinicName}`,
        text: `This is a test message from the ${s.clinicName} booking system. If you can read it, email notifications are working.\n\n— ${s.clinicName}`,
        kind: 'test',
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      });
      return { id: ref.id, to };
    },
  ],
  mailStatus: [
    'admin',
    async ({ data }) => {
      const snap = await db.collection('mail').doc(String(data?.id ?? '')).get();
      if (!snap.exists || snap.data().kind !== 'test') throw new HttpsError('not-found', 'Unknown test email');
      const m = snap.data();
      return { status: m.status, error: m.error ?? null };
    },
  ],
};

function toHttpsError(e) {
  if (e instanceof HttpsError) return e;
  if (e instanceof ValidationError) return new HttpsError('invalid-argument', e.message);
  if (e instanceof ConflictError) return new HttpsError('already-exists', e.message);
  if (e instanceof NotFoundError) return new HttpsError('not-found', e.message);
  if (e instanceof PermissionError) return new HttpsError('permission-denied', e.message);
  logger.error(e);
  return new HttpsError('internal', 'Something went wrong. Please try again.');
}

export const api = onCall({ cors: true }, async (req) => {
  const { service, hooks, setup } = context();
  await setup;
  const op = String(req.data?.op ?? '');
  const data = req.data?.data ?? {};
  const auth = req.auth ?? null;
  const ip = req.rawRequest?.ip ?? 'unknown';
  try {
    if (op.startsWith('ext:')) {
      const action = hooks.action(op.slice(4));
      if (!action) throw new HttpsError('not-found', 'Unknown action');
      await requireAuth(action.auth, auth, service);
      return await action.handler({ data, auth });
    }
    const entry = OPS[op];
    if (!entry) throw new HttpsError('not-found', 'Unknown operation');
    await requireAuth(entry[0], auth, service);
    return await entry[1]({ service, auth, data, ip });
  } catch (e) {
    throw toHttpsError(e);
  }
});

export const sendMail = onDocumentCreated({ document: 'mail/{id}', secrets: [SMTP_PASSWORD] }, async (event) => {
  const mail = event.data?.data();
  if (!mail || mail.status !== 'pending') return;
  const result = await deliver(mail, {
    host: SMTP_HOST.value(),
    port: Number(SMTP_PORT.value()),
    user: SMTP_USER.value(),
    from: MAIL_FROM.value(),
    password: SMTP_PASSWORD.value(),
  });
  if (result.status === 'error') logger.warn('mail failed', { id: event.params.id, error: result.error });
  await event.data.ref.update({ ...result, processedAt: new Date() });
});

export const reminders = onSchedule({ schedule: 'every 10 minutes' }, async () => {
  const { service, setup } = context();
  await setup;
  const sent = await service.sweepReminders();
  if (sent) logger.info(`reminders sent: ${sent}`);
});

export const nightly = onSchedule({ schedule: '5 0 * * *', timeZone: 'Asia/Karachi' }, async () => {
  const { service, setup } = context();
  await setup;
  await service.rebuildWindow();
});
