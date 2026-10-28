// Clinic rules on Firestore (Admin SDK). The Cloud Functions in index.js are thin
// wrappers around this class; the clock and hook bus are injected for tests.
import { randomInt } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { EVENTS } from './hooks.js';
import {
  DEFAULT_WEEKLY,
  STATUSES,
  bookableSlots,
  daySchedule,
  isInside,
  normalizePhone,
  validateOverride,
  validatePatientDetails,
  validateSettingsPatch,
  validateWeekly,
  withDefaults,
} from './core/schedule.js';
import { ValidationError } from './core/slots.js';
import { addDays, fromHHMM, isValidDate, nowInTz, toHHMM, zonedToUtc } from './core/time.js';

export { ValidationError };
export class ConflictError extends Error {}
export class NotFoundError extends Error {}
export class PermissionError extends Error {}

export const ROLES = ['patient', 'admin'];

// Settings only the admin may read (settings/clinic is public).
const PRIVATE_SETTINGS = ['adminEmail'];
const REF_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O, 1/I
const ACTIVE = (a) => a.status !== 'cancelled';

export function publicAppointment(a) {
  const iso = (t) => (t?.toDate ? t.toDate().toISOString() : t ?? null);
  return {
    id: a.ref,
    ref: a.ref,
    date: a.date,
    start: a.start,
    end: a.end,
    startAt: iso(a.startAt),
    patientName: a.patientName,
    phone: a.phone,
    email: a.email,
    reason: a.reason,
    status: a.status,
    bookedBy: a.bookedBy,
    cancelledBy: a.cancelledBy ?? null,
    patientUid: a.patientUid ?? null,
    paymentStatus: a.paymentStatus ?? 'not_required',
    createdAt: iso(a.createdAt),
  };
}

function assertDate(d) {
  if (!isValidDate(d)) throw new ValidationError('Invalid date (use YYYY-MM-DD)');
}

export class ClinicService {
  constructor(db, { hooks, now = () => new Date() }) {
    this.db = db;
    this.hooks = hooks;
    this.now = now;
  }

  // ---------- references ----------

  get settingsRef() {
    return this.db.doc('settings/clinic');
  }
  get privateRef() {
    return this.db.doc('settings/private');
  }
  get weeklyRef() {
    return this.db.doc('settings/weekly');
  }
  apptRef(ref) {
    return this.db.collection('appointments').doc(ref);
  }
  apptsOn(date) {
    return this.db.collection('appointments').where('date', '==', date);
  }

  // ---------- configuration ----------

  async settings() {
    const [pub, priv] = await Promise.all([this.settingsRef.get(), this.privateRef.get()]);
    return withDefaults({ ...pub.data(), ...priv.data() });
  }

  async weekly() {
    const w = await this.weeklyRef.get();
    return w.exists ? w.data().days : DEFAULT_WEEKLY;
  }

  clinicNow(settings) {
    return nowInTz(settings.timezone, this.now());
  }

  /** Writes default settings once, so the public page has something to read. */
  async ensureSetup() {
    const [s, w] = await Promise.all([this.settingsRef.get(), this.weeklyRef.get()]);
    const batch = this.db.batch();
    if (!s.exists) {
      const { adminEmail, ...pub } = withDefaults({});
      batch.set(this.settingsRef, pub);
      batch.set(this.privateRef, { adminEmail }, { merge: true });
    }
    if (!w.exists) batch.set(this.weeklyRef, { days: DEFAULT_WEEKLY });
    await batch.commit();
    if (!s.exists || !w.exists) await this.rebuildWindow();
  }

  async saveSettings(patch) {
    const clean = validateSettingsPatch(patch);
    const pub = Object.fromEntries(Object.entries(clean).filter(([k]) => !PRIVATE_SETTINGS.includes(k)));
    const priv = Object.fromEntries(Object.entries(clean).filter(([k]) => PRIVATE_SETTINGS.includes(k)));
    const batch = this.db.batch();
    if (Object.keys(pub).length) batch.set(this.settingsRef, pub, { merge: true });
    if (Object.keys(priv).length) batch.set(this.privateRef, priv, { merge: true });
    await batch.commit();
    return this.afterHoursChange();
  }

  async saveWeekly(days) {
    await this.weeklyRef.set({ days: validateWeekly(days) });
    return this.afterHoursChange();
  }

  /** override null = back to the weekly timetable / not activated. */
  async setDays(dates, override) {
    if (!Array.isArray(dates) || dates.length === 0 || dates.length > 62) throw new ValidationError('Choose 1–62 dates');
    dates.forEach(assertDate);
    const clean = override === null ? null : validateOverride(override);
    const batch = this.db.batch();
    for (const d of new Set(dates)) {
      const ref = this.db.doc(`dayOverrides/${d}`);
      if (clean) batch.set(ref, { ...clean, date: d, updatedAt: FieldValue.serverTimestamp() });
      else batch.delete(ref);
    }
    await batch.commit();
    return this.afterHoursChange([...new Set(dates)]);
  }

  async afterHoursChange(dates) {
    if (dates) await this.rebuildDays(dates);
    else await this.rebuildWindow();
    const outsideHours = await this.outsideHours();
    await this.hooks.emit(EVENTS.HOURS_CHANGED, { outsideHours });
    return { settings: await this.settings(), outsideHours };
  }

  // ---------- public day documents ----------

  async overrideFor(date, tx) {
    const ref = this.db.doc(`dayOverrides/${date}`);
    const snap = tx ? await tx.get(ref) : await ref.get();
    return snap.exists ? snap.data() : null;
  }

  dayDoc(date, schedule, taken, settings) {
    return {
      date,
      open: schedule.slots.length > 0,
      source: schedule.source,
      slotMinutes: settings.slotMinutes,
      slots: schedule.slots.map((x) => ({ start: toHHMM(x.start), end: toHHMM(x.end) })),
      taken: taken.map((x) => ({ start: toHHMM(x.start), end: toHHMM(x.end) })),
      updatedAt: FieldValue.serverTimestamp(),
    };
  }

  async rebuildDays(dates) {
    const [settings, weekly] = await Promise.all([this.settings(), this.weekly()]);
    let batch = this.db.batch();
    let n = 0;
    for (const date of dates) {
      const [override, appts] = await Promise.all([this.overrideFor(date), this.apptsOn(date).get()]);
      const taken = appts.docs.map((d) => d.data()).filter(ACTIVE).map((a) => ({ start: fromHHMM(a.start), end: fromHHMM(a.end) }));
      batch.set(this.db.doc(`days/${date}`), this.dayDoc(date, daySchedule(date, settings, weekly, override), taken, settings));
      if (++n % 400 === 0) {
        await batch.commit();
        batch = this.db.batch();
      }
    }
    await batch.commit();
  }

  /** Today through the end of the booking window (plus one spare day). */
  async rebuildWindow() {
    const settings = await this.settings();
    const { date } = this.clinicNow(settings);
    const dates = Array.from({ length: settings.bookingWindowDays + 2 }, (_, i) => addDays(date, i));
    await this.rebuildDays(dates);
    return dates.length;
  }

  // ---------- booking ----------

  /**
   * input: {date, start, name, phone, email, reason}
   * ctx:   {uid, profile, byAdmin}. A signed-in patient's name/phone/email come from their profile.
   */
  async book(input, { uid = null, profile = null, byAdmin = false } = {}) {
    const settings = await this.settings();
    if (!byAdmin && settings.requireLogin && !uid) throw new PermissionError('Please log in or create an account to book.');
    if (!byAdmin && uid && !profile) throw new PermissionError('Please complete your profile before booking.');
    const details =
      uid && !byAdmin
        ? validatePatientDetails({ name: profile.name, phone: profile.phone, email: profile.email, reason: input?.reason })
        : validatePatientDetails(input);
    const date = input?.date;
    assertDate(date);
    const start = fromHHMM(input?.start);
    if (start === null) throw new ValidationError('Choose a time slot');

    if (uid && !byAdmin) {
      const upcoming = await this.db
        .collection('appointments')
        .where('patientUid', '==', uid)
        .where('status', '==', 'booked')
        .where('startAt', '>', Timestamp.fromDate(this.now()))
        .count()
        .get();
      if (upcoming.data().count >= settings.maxUpcomingPerPatient) {
        throw new ConflictError(`You already have ${upcoming.data().count} upcoming appointments. Please attend or cancel one first.`);
      }
    }

    const weekly = await this.weekly();
    const extra = this.hooks.applyFilters('booking.beforeCreate', { paymentStatus: 'not_required', extras: {} }, { input, uid, byAdmin, settings });

    const appointment = await this.db.runTransaction(async (tx) => {
      const override = await this.overrideFor(date, tx);
      const apptsSnap = await tx.get(this.apptsOn(date));
      const active = apptsSnap.docs.map((d) => d.data()).filter(ACTIVE);
      const taken = active.map((a) => ({ start: fromHHMM(a.start), end: fromHHMM(a.end) }));
      const schedule = daySchedule(date, settings, weekly, override);
      const slot = bookableSlots({ date, slots: schedule.slots, taken, now: this.clinicNow(settings), settings, forAdmin: byAdmin }).find(
        (x) => x.start === start,
      );
      if (!slot) throw new ConflictError('Sorry, that time slot is no longer available. Please choose another.');
      if (!byAdmin && active.some((a) => a.status === 'booked' && a.phone === details.phone)) {
        throw new ConflictError('This phone number already has an appointment on that day.');
      }

      let ref;
      for (let i = 0; i < 6 && !ref; i++) {
        const candidate = Array.from({ length: 6 }, () => REF_ALPHABET[randomInt(REF_ALPHABET.length)]).join('');
        if (!(await tx.get(this.apptRef(candidate))).exists) ref = candidate;
      }
      if (!ref) throw new Error('Could not allocate a booking reference');

      const doc = {
        ref,
        date,
        start: toHHMM(slot.start),
        end: toHHMM(slot.end),
        startAt: Timestamp.fromDate(zonedToUtc(date, slot.start, settings.timezone)),
        endAt: Timestamp.fromDate(zonedToUtc(date, slot.end, settings.timezone)),
        patientUid: byAdmin ? null : uid,
        patientName: details.name,
        phone: details.phone,
        email: details.email,
        reason: details.reason,
        status: 'booked',
        bookedBy: byAdmin ? 'admin' : 'patient',
        cancelledBy: null,
        paymentStatus: extra.paymentStatus,
        extras: extra.extras,
        reminders: { r24: false, r1: false },
        createdAt: Timestamp.fromDate(this.now()),
      };
      tx.create(this.apptRef(ref), doc);
      tx.set(this.db.doc(`days/${date}`), this.dayDoc(date, schedule, [...taken, slot], settings));
      return doc;
    });

    const pub = publicAppointment(appointment);
    await this.hooks.emit(EVENTS.APPOINTMENT_BOOKED, { appointment: pub, by: byAdmin ? 'admin' : 'patient' });
    return pub;
  }

  /** Cancel by a patient: signed in (uid must own it) or guest (ref + phone). */
  async cancelByPatient(ref, { uid = null, phone = null } = {}) {
    const a = await this.findForPatient(ref, { uid, phone });
    if (a.status !== 'booked') throw new ConflictError('This appointment is not active.');
    if (a.startAt && new Date(a.startAt) <= this.now()) throw new ConflictError('This appointment has already started.');
    return this.changeStatus(a.ref, 'cancelled', 'patient');
  }

  async setStatusByAdmin(ref, status) {
    if (!STATUSES.includes(status)) throw new ValidationError('Unknown status');
    return this.changeStatus(String(ref ?? ''), status, 'admin');
  }

  async changeStatus(ref, status, by) {
    const settings = await this.settings();
    const weekly = await this.weekly();
    const { before, after } = await this.db.runTransaction(async (tx) => {
      const snap = await tx.get(this.apptRef(ref));
      if (!snap.exists) throw new NotFoundError('Appointment not found');
      const a = snap.data();
      const override = await this.overrideFor(a.date, tx);
      const others = (await tx.get(this.apptsOn(a.date))).docs.map((d) => d.data()).filter((x) => x.ref !== ref && ACTIVE(x));
      if (a.status === 'cancelled' && status !== 'cancelled') {
        const s = fromHHMM(a.start);
        const e = fromHHMM(a.end);
        if (others.some((o) => fromHHMM(o.start) < e && s < fromHHMM(o.end))) throw new ConflictError('That time is now taken by another appointment.');
      }
      const patch = { status, updatedAt: Timestamp.fromDate(this.now()) };
      if (status === 'cancelled') patch.cancelledBy = by;
      tx.update(snap.ref, patch);
      const nowActive = status === 'cancelled' ? others : [...others, a];
      const taken = nowActive.map((x) => ({ start: fromHHMM(x.start), end: fromHHMM(x.end) }));
      tx.set(this.db.doc(`days/${a.date}`), this.dayDoc(a.date, daySchedule(a.date, settings, weekly, override), taken, settings));
      return { before: a, after: { ...a, ...patch } };
    });
    const pub = publicAppointment(after);
    if (status === 'cancelled' && before.status !== 'cancelled') await this.hooks.emit(EVENTS.APPOINTMENT_CANCELLED, { appointment: pub, by });
    else if (before.status !== status) await this.hooks.emit(EVENTS.APPOINTMENT_STATUS, { appointment: pub, from: before.status, to: status });
    return pub;
  }

  async findForPatient(ref, { uid = null, phone = null }) {
    const snap = await this.apptRef(String(ref ?? '').trim().toUpperCase()).get();
    const a = snap.exists ? snap.data() : null;
    const ok = a && ((uid && a.patientUid === uid) || (phone && normalizePhone(phone) && a.phone === normalizePhone(phone)));
    if (!ok) throw new NotFoundError('No appointment found for those details.');
    return publicAppointment(a);
  }

  /** Links a booking made without an account (or by the clinic) to the signed-in patient. */
  async claim(ref, phone, uid) {
    const a = await this.findForPatient(ref, { phone });
    if (a.patientUid && a.patientUid !== uid) throw new ConflictError('This booking already belongs to another account.');
    if (a.patientUid === uid) return a;
    await this.apptRef(a.ref).update({ patientUid: uid });
    const pub = { ...a, patientUid: uid };
    await this.hooks.emit(EVENTS.APPOINTMENT_CLAIMED, { appointment: pub, uid });
    return pub;
  }

  /** Upcoming booked appointments that no longer fit the opening hours. */
  async outsideHours() {
    const settings = await this.settings();
    const weekly = await this.weekly();
    const snap = await this.db
      .collection('appointments')
      .where('status', '==', 'booked')
      .where('startAt', '>', Timestamp.fromDate(this.now()))
      .get();
    const cache = new Map();
    const out = [];
    for (const d of snap.docs) {
      const a = d.data();
      if (!cache.has(a.date)) cache.set(a.date, daySchedule(a.date, settings, weekly, await this.overrideFor(a.date)).intervals);
      if (!isInside(cache.get(a.date), fromHHMM(a.start), fromHHMM(a.end))) out.push(publicAppointment(a));
    }
    return out.sort((x, y) => (x.startAt < y.startAt ? -1 : 1));
  }

  // ---------- reminders ----------

  /** Run every few minutes. Sends a day-before and an hour-before reminder once each. */
  async sweepReminders() {
    const now = this.now();
    const snap = await this.db
      .collection('appointments')
      .where('status', '==', 'booked')
      .where('startAt', '>', Timestamp.fromDate(now))
      .where('startAt', '<=', Timestamp.fromDate(new Date(now.getTime() + 25 * 3600_000)))
      .get();
    let sent = 0;
    for (const d of snap.docs) {
      const a = d.data();
      const until = (a.startAt.toMillis() - now.getTime()) / 60000;
      const lead = (a.startAt.toMillis() - a.createdAt.toMillis()) / 60000;
      let kind = null;
      // Skip a reminder that would arrive right after the booking confirmation.
      if (!a.reminders?.r24 && until <= 1440 && until > 90 && lead > 1440 + 60) kind = 'r24';
      else if (!a.reminders?.r1 && until <= 60 && lead > 120) kind = 'r1';
      if (!kind) continue;
      await d.ref.update({ [`reminders.${kind}`]: true });
      await this.hooks.emit(EVENTS.APPOINTMENT_REMINDER, { appointment: publicAppointment(a), kind });
      sent++;
    }
    return sent;
  }

  // ---------- users & roles ----------
  // users/{uid}: {name, phone, email, role, createdAt, updatedAt, lastLoginAt}. Every account
  // is a user; `role` decides what it may do ('patient' or 'admin'; more roles can be added
  // to ROLES). Firestore rules and the api function both read the role from this document.

  userRef(uid) {
    return this.db.doc(`users/${uid}`);
  }

  /** Creates or updates the signed-in user's own details. New accounts start as patients. */
  async saveProfile(uid, email, input) {
    const { name, phone } = validatePatientDetails({ name: input?.name, phone: input?.phone, email });
    const ref = this.userRef(uid);
    const snap = await ref.get();
    const isNew = !snap.exists || !snap.data().name;
    const data = { name, phone, email: email ?? '', updatedAt: Timestamp.fromDate(this.now()) };
    if (!snap.data()?.role) data.role = 'patient';
    if (!snap.data()?.createdAt) data.createdAt = Timestamp.fromDate(this.now());
    await ref.set(data, { merge: true });
    const user = { uid, name, phone, email: email ?? '', role: snap.data()?.role ?? 'patient' };
    if (isNew && user.role === 'patient') await this.hooks.emit(EVENTS.PATIENT_REGISTERED, { patient: user });
    return user;
  }

  async profile(uid) {
    const snap = await this.userRef(uid).get();
    return snap.exists ? { uid, ...snap.data() } : null;
  }

  async role(uid) {
    if (!uid) return null;
    const snap = await this.userRef(uid).get();
    return snap.exists ? snap.data().role ?? 'patient' : null;
  }

  /** Records the login time of an existing user (a brand-new sign-up has no document yet). */
  async touchLogin(uid) {
    await this.userRef(uid)
      .update({ lastLoginAt: Timestamp.fromDate(this.now()) })
      .catch((e) => {
        if (e.code !== 5) throw e; // 5 = NOT_FOUND
      });
  }

  /**
   * First-time admin: an account whose email is in `allowedEmails`. Emails are not verified,
   * so each listed address can be claimed once; the claiming uids are kept in
   * settings/private.adminUids.
   */
  async bootstrapAdmin(uid, email, allowedEmails) {
    const allowed = allowedEmails.map((e) => e.trim().toLowerCase()).filter(Boolean);
    const mail = String(email ?? '').toLowerCase();
    if (!mail || !allowed.includes(mail)) throw new PermissionError('This account is not a clinic admin.');
    await this.db.runTransaction(async (tx) => {
      const priv = await tx.get(this.privateRef);
      const user = await tx.get(this.userRef(uid));
      const uids = priv.data()?.adminUids ?? [];
      if (!uids.includes(uid)) {
        if (uids.length >= allowed.length) throw new PermissionError('The clinic admin accounts are already set up. Ask an admin to give you access.');
        tx.set(this.privateRef, { adminUids: [...uids, uid] }, { merge: true });
      }
      const base = user.exists ? {} : { email: mail, name: '', phone: '', createdAt: Timestamp.fromDate(this.now()) };
      tx.set(this.userRef(uid), { ...base, role: 'admin', updatedAt: Timestamp.fromDate(this.now()) }, { merge: true });
    });
    return { role: 'admin' };
  }

  /** An admin changes someone's role. Admins cannot demote themselves or remove the last admin. */
  async setRole(actorUid, uid, role) {
    if (!ROLES.includes(role)) throw new ValidationError(`Role must be one of: ${ROLES.join(', ')}`);
    const result = await this.db.runTransaction(async (tx) => {
      const snap = await tx.get(this.userRef(String(uid ?? '')));
      if (!snap.exists) throw new NotFoundError('User not found');
      const from = snap.data().role ?? 'patient';
      if (from === role) return { from, to: role };
      if (from === 'admin') {
        if (uid === actorUid) throw new ConflictError('You cannot remove your own admin role. Ask another admin.');
        const admins = await tx.get(this.db.collection('users').where('role', '==', 'admin'));
        if (admins.size <= 1) throw new ConflictError('There must be at least one admin.');
      }
      tx.update(snap.ref, { role, updatedAt: Timestamp.fromDate(this.now()) });
      return { from, to: role };
    });
    if (result.from !== result.to) await this.hooks.emit(EVENTS.USER_ROLE_CHANGED, { uid, ...result });
    return { uid, role };
  }

  /**
   * Deletes the signed-in user's own account data (Google Play account-deletion rule).
   *   - upcoming booked appointments are cancelled as by the patient, so the slots open
   *     again and the admin is told through the usual cancellation hook;
   *   - every appointment of theirs is then anonymised, not deleted: the clinic keeps the
   *     date, time and outcome (its visit history and day documents stay consistent), but
   *     the name, phone, email, visit reason and the link to the account are removed;
   *   - their in-app notifications, already-processed emails and users/{uid} are deleted.
   * The caller deletes the Firebase Auth login afterwards. Safe to repeat if that fails.
   * The last admin cannot delete their account. An admin's uid stays in
   * settings/private.adminUids so their email cannot claim admin again.
   */
  async deleteAccount(uid) {
    const user = await this.profile(uid);
    if (user?.role === 'admin') {
      const admins = await this.db.collection('users').where('role', '==', 'admin').count().get();
      if (admins.data().count <= 1) throw new ConflictError('You are the only admin. Make someone else an admin before deleting your account.');
    }
    const mine = (await this.db.collection('appointments').where('patientUid', '==', uid).get()).docs.map((d) => d.data());
    let cancelled = 0;
    for (const a of mine) {
      if (a.status !== 'booked' || a.startAt.toDate() <= this.now()) continue;
      await this.changeStatus(a.ref, 'cancelled', 'patient');
      cancelled++;
    }

    const anon = { patientUid: null, patientName: 'Deleted user', phone: '', email: '', reason: '', anonymisedAt: Timestamp.fromDate(this.now()) };
    const emails = new Set([user?.email, ...mine.map((a) => a.email)].filter(Boolean));
    const refs = [
      ...mine.map((a) => ({ ref: this.apptRef(a.ref), patch: anon })),
      ...(await this.db.collection('notifications').where('uid', '==', uid).get()).docs.map((d) => ({ ref: d.ref })),
      // Sent or failed emails only; pending ones (e.g. the cancellation notices above) still go out.
      ...(
        await Promise.all([...emails].map((to) => this.db.collection('mail').where('to', '==', to).get()))
      ).flatMap((q) => q.docs.filter((d) => d.data().status !== 'pending').map((d) => ({ ref: d.ref }))),
      { ref: this.userRef(uid) },
    ];
    for (let i = 0; i < refs.length; i += 400) {
      const batch = this.db.batch();
      for (const { ref, patch } of refs.slice(i, i + 400)) {
        if (patch) batch.update(ref, patch);
        else batch.delete(ref);
      }
      await batch.commit();
    }
    await this.hooks.emit(EVENTS.USER_DELETED, { uid, role: user?.role ?? null });
    return { cancelled, anonymised: mine.length };
  }

  /**
   * One-time move from the old `patients` collection and email-list admins to `users`.
   * Safe to run repeatedly; never overwrites an existing user's role.
   */
  async migrateUsers(lookupEmail) {
    let moved = 0;
    const old = await this.db.collection('patients').get();
    for (const d of old.docs) {
      const ref = this.userRef(d.id);
      if ((await ref.get()).exists) continue;
      await ref.set({ ...d.data(), role: 'patient' });
      moved++;
    }
    const adminUids = (await this.privateRef.get()).data()?.adminUids ?? [];
    for (const uid of adminUids) {
      const ref = this.userRef(uid);
      const snap = await ref.get();
      if (snap.exists && snap.data().role === 'admin') continue;
      const base = snap.exists ? {} : { email: (await lookupEmail(uid)) ?? '', name: '', phone: '', createdAt: Timestamp.fromDate(this.now()) };
      await ref.set({ ...base, role: 'admin' }, { merge: true });
      moved++;
    }
    return moved;
  }
}
