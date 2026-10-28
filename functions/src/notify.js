// Turns clinic events into notifications.
//   in-app: documents in `notifications` (patients see their own, the admin sees audience 'admin')
//   email:  documents in `mail`, sent by the sendMail function (see mail.js)
// More channels (SMS, WhatsApp, push) can listen to EVENTS.NOTIFICATION_CREATED.
import { FieldValue } from 'firebase-admin/firestore';
import { EVENTS } from './hooks.js';

const DOW = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function dateLong(date) {
  const d = new Date(`${date}T00:00:00Z`);
  return `${DOW[d.getUTCDay()]}, ${d.getUTCDate()} ${MON[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

export function time12(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  if (h === 24) return '12:00 AM';
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
}

const when = (a) => `${dateLong(a.date)} at ${time12(a.start)}`;

/** Message texts. Each returns {title, body}; `s` is the clinic settings. */
export const TEMPLATES = {
  booked: (a, s) => ({
    title: 'Appointment confirmed',
    body: `Your appointment with ${s.doctorName || s.clinicName} is booked for ${when(a)} (clinic time). Booking reference: ${a.ref}.${s.instructions ? ` ${s.instructions}` : ''}`,
  }),
  cancelledByPatient: (a) => ({ title: 'Appointment cancelled', body: `You cancelled your appointment on ${when(a)} (ref ${a.ref}).` }),
  cancelledByClinic: (a, s) => ({
    title: 'Appointment cancelled by the clinic',
    body: `${s.clinicName} has cancelled your appointment on ${when(a)} (ref ${a.ref}). Please book another time.`,
  }),
  completed: (a, s) => ({ title: 'Thank you for your visit', body: `Your appointment on ${when(a)} with ${s.doctorName || s.clinicName} is complete.` }),
  noShow: (a) => ({ title: 'Missed appointment', body: `You missed your appointment on ${when(a)} (ref ${a.ref}). You are welcome to book another time.` }),
  restored: (a) => ({ title: 'Appointment restored', body: `Your appointment on ${when(a)} (ref ${a.ref}) is active again.` }),
  r24: (a, s) => ({ title: 'Reminder: appointment tomorrow', body: `Reminder: your appointment with ${s.doctorName || s.clinicName} is on ${when(a)}. Ref ${a.ref}.` }),
  r1: (a) => ({ title: 'Your appointment starts soon', body: `Your appointment starts at ${time12(a.start)} today (ref ${a.ref}). Please be ready.` }),
  outsideHours: (a, s) => ({
    title: 'Your appointment may need to change',
    body: `The clinic's hours changed and your appointment on ${when(a)} (ref ${a.ref}) is outside them. ${s.clinicName} will contact you, or you can cancel and rebook.`,
  }),
  claimed: (a) => ({ title: 'Booking added to your account', body: `Your appointment on ${when(a)} (ref ${a.ref}) is now in your account.` }),
  welcome: (p, s) => ({ title: `Welcome to ${s.clinicName}`, body: `Hello ${p.name}, your account is ready. You can book appointments and see them under "My appointments".` }),
  adminNewBooking: (a) => ({ title: 'New booking', body: `${a.patientName} (${a.phone}) booked ${when(a)}. Ref ${a.ref}.${a.reason ? ` Reason: ${a.reason}` : ''}` }),
  adminCancelled: (a) => ({ title: 'Patient cancelled', body: `${a.patientName} cancelled ${when(a)} (ref ${a.ref}). The slot is free again.` }),
  adminNewPatient: (p) => ({ title: 'New patient account', body: `${p.name} (${p.phone}${p.email ? `, ${p.email}` : ''}) created an account.` }),
  adminOutside: (list) => ({
    title: `${list.length} appointment${list.length > 1 ? 's' : ''} outside opening hours`,
    body: list.slice(0, 5).map((a) => `${when(a)} – ${a.patientName} (${a.phone})`).join('; ') + (list.length > 5 ? '…' : ''),
  }),
};

export function registerNotifications({ db, hooks, service, siteUrl }) {
  async function notify({ audience, uid = null, appointmentId = null, kind, msg, email = '', settings }) {
    const tasks = [];
    if (audience === 'admin' || uid) {
      const doc = { audience, uid, kind, title: msg.title, body: msg.body, appointmentId, read: false, createdAt: FieldValue.serverTimestamp() };
      tasks.push(
        db
          .collection('notifications')
          .add(doc)
          .then((ref) => hooks.emit(EVENTS.NOTIFICATION_CREATED, { notification: { id: ref.id, ...doc }, email })),
      );
    }
    if (email && settings.emailNotifications) {
      const link = siteUrl ? `\n\n${audience === 'admin' ? `${siteUrl}/admin.html` : siteUrl}` : '';
      tasks.push(
        db.collection('mail').add({
          to: email,
          subject: `${msg.title} – ${settings.clinicName}`,
          text: `${msg.body}${link}\n\n— ${settings.clinicName}`,
          kind,
          appointmentId,
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
        }),
      );
    }
    await Promise.all(tasks);
  }

  const toPatient = async (a, kind, msgFn) => {
    const s = await service.settings();
    await notify({ audience: 'patient', uid: a.patientUid, appointmentId: a.ref, kind, msg: msgFn(a, s), email: a.email, settings: s });
  };
  const toAdmin = async (kind, msg, appointmentId = null) => {
    const s = await service.settings();
    await notify({ audience: 'admin', appointmentId, kind, msg, email: s.adminEmail, settings: s });
  };

  hooks.on(EVENTS.APPOINTMENT_BOOKED, async ({ appointment: a }) => {
    await toPatient(a, 'booked', TEMPLATES.booked);
    await toAdmin('admin_new_booking', TEMPLATES.adminNewBooking(a), a.ref);
  });

  hooks.on(EVENTS.APPOINTMENT_CANCELLED, async ({ appointment: a, by }) => {
    if (by === 'patient') {
      await toPatient(a, 'cancelled', TEMPLATES.cancelledByPatient);
      await toAdmin('admin_cancelled', TEMPLATES.adminCancelled(a), a.ref);
    } else {
      await toPatient(a, 'cancelled_by_clinic', TEMPLATES.cancelledByClinic);
    }
  });

  hooks.on(EVENTS.APPOINTMENT_STATUS, async ({ appointment: a, to }) => {
    if (to === 'completed') await toPatient(a, 'completed', TEMPLATES.completed);
    if (to === 'no_show') await toPatient(a, 'no_show', TEMPLATES.noShow);
    if (to === 'booked') await toPatient(a, 'restored', TEMPLATES.restored);
  });

  hooks.on(EVENTS.APPOINTMENT_REMINDER, ({ appointment: a, kind }) => toPatient(a, kind, TEMPLATES[kind]));

  hooks.on(EVENTS.APPOINTMENT_CLAIMED, async ({ appointment: a }) => {
    const s = await service.settings();
    await notify({ audience: 'patient', uid: a.patientUid, appointmentId: a.ref, kind: 'claimed', msg: TEMPLATES.claimed(a, s), settings: s });
  });

  hooks.on(EVENTS.PATIENT_REGISTERED, async ({ patient: p }) => {
    const s = await service.settings();
    await notify({ audience: 'patient', uid: p.uid, kind: 'welcome', msg: TEMPLATES.welcome(p, s), settings: s });
    await toAdmin('admin_new_patient', TEMPLATES.adminNewPatient(p));
  });

  // Tell each affected patient once per appointment; give the admin one summary.
  hooks.on(EVENTS.HOURS_CHANGED, async ({ outsideHours }) => {
    if (!outsideHours.length) return;
    const fresh = [];
    for (const a of outsideHours) {
      const ref = db.collection('appointments').doc(a.ref);
      const isNew = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists || snap.data().outsideNotified) return false;
        tx.update(ref, { outsideNotified: true });
        return true;
      });
      if (isNew) {
        fresh.push(a);
        await toPatient(a, 'outside_hours', TEMPLATES.outsideHours);
      }
    }
    if (fresh.length) await toAdmin('admin_outside_hours', TEMPLATES.adminOutside(fresh));
  });

  return { notify };
}
