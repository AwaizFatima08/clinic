// Clinic rules on top of the database. The clock is injected so tests can fix "now".
import { randomBytes, randomInt, scryptSync, timingSafeEqual } from 'node:crypto';
import { DEFAULT_SETTINGS } from './db.js';
import { ValidationError, formatIntervals, freeSlots, isInsideHours, parseIntervals } from './slots.js';
import { addDays, daysBetween, fromHHMM, isValidDate, isValidTimeZone, nowInTz, toHHMM, weekday } from './time.js';

export class ConflictError extends Error {}
export class NotFoundError extends Error {}

const STATUSES = ['booked', 'completed', 'no_show', 'cancelled'];
const REF_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O, 1/I
const SESSION_MS = 12 * 60 * 60 * 1000;

const SETTING_RULES = {
  clinic_name: (v) => str(v, 1, 80),
  doctor_name: (v) => str(v, 0, 80),
  slot_minutes: (v) => int(v, 5, 240),
  timezone: (v) => {
    if (!isValidTimeZone(v)) throw new ValidationError('Unknown time zone');
    return v;
  },
  booking_window_days: (v) => int(v, 1, 365),
  min_notice_minutes: (v) => int(v, 0, 10080),
  schedule_mode: (v) => {
    if (v !== 'weekly' && v !== 'daily') throw new ValidationError('Schedule mode must be weekly or daily');
    return v;
  },
  instructions: (v) => str(v, 0, 1000),
};
const NUMERIC_SETTINGS = ['slot_minutes', 'booking_window_days', 'min_notice_minutes'];

function str(v, min, max) {
  if (typeof v !== 'string') throw new ValidationError('Expected text');
  const s = v.trim();
  if (s.length < min || s.length > max) throw new ValidationError(`Must be ${min}–${max} characters`);
  return s;
}

function int(v, min, max) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new ValidationError(`Must be a whole number from ${min} to ${max}`);
  return n;
}

export function normalizePhone(p) {
  if (typeof p !== 'string') return '';
  const s = p.replace(/[\s\-().]/g, '');
  return /^\+?\d{7,15}$/.test(s) ? s : '';
}

function hashPassword(pw) {
  const salt = randomBytes(16);
  return `${salt.toString('hex')}:${scryptSync(pw, salt, 64).toString('hex')}`;
}

function verifyPassword(pw, stored) {
  const [saltHex, hashHex] = (stored ?? '').split(':');
  if (!saltHex || !hashHex) return false;
  const hash = Buffer.from(hashHex, 'hex');
  return timingSafeEqual(hash, scryptSync(pw, Buffer.from(saltHex, 'hex'), hash.length));
}

function publicAppointment(a) {
  return {
    id: a.id,
    ref: a.ref,
    date: a.date,
    start: toHHMM(a.start_min),
    end: toHHMM(a.end_min),
    patient_name: a.patient_name,
    phone: a.phone,
    email: a.email,
    reason: a.reason,
    status: a.status,
    booked_by: a.booked_by,
    created_at: a.created_at,
  };
}

export class Clinic {
  constructor(db, { now = () => new Date() } = {}) {
    this.db = db;
    this.now = now;
  }

  // ---------- settings & hours ----------

  settings() {
    const s = { ...DEFAULT_SETTINGS };
    for (const { key, value } of this.db.prepare('SELECT key, value FROM settings').all()) s[key] = value;
    for (const k of NUMERIC_SETTINGS) s[k] = Number(s[k]);
    delete s.admin_hash;
    return s;
  }

  updateSettings(patch) {
    const clean = {};
    for (const [k, v] of Object.entries(patch ?? {})) {
      if (!SETTING_RULES[k]) throw new ValidationError(`Unknown setting: ${k}`);
      try {
        clean[k] = SETTING_RULES[k](v);
      } catch (e) {
        throw new ValidationError(`${k.replaceAll('_', ' ')}: ${e.message}`);
      }
    }
    const put = this.db.prepare('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value');
    this.tx(() => {
      for (const [k, v] of Object.entries(clean)) put.run(k, String(v));
    });
    return { settings: this.settings(), outsideHours: this.appointmentsOutsideHours() };
  }

  today() {
    return nowInTz(this.settings().timezone, this.now());
  }

  weekly() {
    const out = Array.from({ length: 7 }, () => []);
    for (const r of this.db.prepare('SELECT weekday, intervals FROM weekly_hours').all()) out[r.weekday] = JSON.parse(r.intervals);
    return out;
  }

  setWeekly(days) {
    if (!Array.isArray(days) || days.length !== 7) throw new ValidationError('Weekly hours need all 7 days');
    const parsed = days.map((d, i) => {
      try {
        return parseIntervals(d);
      } catch (e) {
        throw new ValidationError(`${['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][i]}: ${e.message}`);
      }
    });
    const put = this.db.prepare('INSERT INTO weekly_hours (weekday, intervals) VALUES (?, ?) ON CONFLICT(weekday) DO UPDATE SET intervals = excluded.intervals');
    this.tx(() => parsed.forEach((iv, d) => put.run(d, JSON.stringify(iv))));
    return { weekly: this.weekly().map(formatIntervals), outsideHours: this.appointmentsOutsideHours() };
  }

  /** Opening hours that apply to one date, and where they come from. */
  dayHours(date) {
    const o = this.db.prepare('SELECT intervals FROM day_overrides WHERE date = ?').get(date);
    if (o) return { source: 'day', intervals: JSON.parse(o.intervals) };
    if (this.settings().schedule_mode === 'daily') return { source: 'not_activated', intervals: [] };
    return { source: 'weekly', intervals: this.weekly()[weekday(date)] };
  }

  setDay(date, list) {
    assertDate(date);
    const iv = parseIntervals(list);
    this.db
      .prepare('INSERT INTO day_overrides (date, intervals) VALUES (?, ?) ON CONFLICT(date) DO UPDATE SET intervals = excluded.intervals')
      .run(date, JSON.stringify(iv));
    return { day: this.adminDay(date), outsideHours: this.appointmentsOutsideHours() };
  }

  clearDay(date) {
    assertDate(date);
    this.db.prepare('DELETE FROM day_overrides WHERE date = ?').run(date);
    return { day: this.adminDay(date), outsideHours: this.appointmentsOutsideHours() };
  }

  /** Upcoming active appointments that no longer fit inside the opening hours. */
  appointmentsOutsideHours() {
    const { date, minutes } = this.today();
    const rows = this.db
      .prepare("SELECT * FROM appointments WHERE status = 'booked' AND (date > ? OR (date = ? AND end_min > ?)) ORDER BY date, start_min")
      .all(date, date, minutes);
    return rows.filter((a) => !isInsideHours(this.dayHours(a.date).intervals, a.start_min, a.end_min)).map(publicAppointment);
  }

  // ---------- slots ----------

  /** Free slots for a date. Patients are limited by the booking window and minimum notice; the admin only by the clock. */
  slots(date, { forAdmin = false } = {}) {
    assertDate(date);
    const s = this.settings();
    const now = nowInTz(s.timezone, this.now());
    const offset = daysBetween(now.date, date);
    if (offset < 0) return [];
    if (!forAdmin && offset > s.booking_window_days) return [];
    const notice = forAdmin ? 0 : s.min_notice_minutes;
    const taken = this.db
      .prepare("SELECT start_min, end_min FROM appointments WHERE date = ? AND status != 'cancelled'")
      .all(date);
    return freeSlots({
      intervals: this.dayHours(date).intervals,
      slotMinutes: s.slot_minutes,
      taken,
      earliestStart: now.minutes + notice - offset * 1440,
    });
  }

  /** Each day in the patient booking window with its number of free slots. */
  publicDays() {
    const s = this.settings();
    const { date: today } = this.today();
    const days = [];
    for (let i = 0; i <= s.booking_window_days; i++) {
      const date = addDays(today, i);
      const open = this.dayHours(date).intervals.length > 0;
      days.push({ date, open, free: open ? this.slots(date).length : 0 });
    }
    return days;
  }

  adminDay(date) {
    const { source, intervals } = this.dayHours(date);
    const counts = this.db
      .prepare("SELECT COUNT(*) AS n FROM appointments WHERE date = ? AND status != 'cancelled'")
      .get(date);
    return {
      date,
      weekday: weekday(date),
      source,
      intervals: formatIntervals(intervals),
      weeklyIntervals: formatIntervals(this.weekly()[weekday(date)]),
      appointments: counts.n,
      free: this.slots(date, { forAdmin: true }).length,
    };
  }

  adminDays(from, count) {
    assertDate(from);
    const n = int(count, 1, 62);
    return Array.from({ length: n }, (_, i) => this.adminDay(addDays(from, i)));
  }

  // ---------- appointments ----------

  book(input, { byAdmin = false } = {}) {
    const date = input?.date;
    assertDate(date);
    const start = fromHHMM(input?.start);
    if (start === null) throw new ValidationError('Choose a time slot');
    let name;
    try {
      name = str(input?.name, 2, 80);
    } catch {
      throw new ValidationError('Please enter the patient name (2–80 characters)');
    }
    const phone = normalizePhone(input?.phone);
    if (!phone) throw new ValidationError('Please enter a valid phone number (7–15 digits, + allowed)');
    const email = typeof input?.email === 'string' ? input.email.trim() : '';
    if (email && (email.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) throw new ValidationError('Please enter a valid email address or leave it empty');
    const reason = typeof input?.reason === 'string' ? input.reason.trim().slice(0, 500) : '';

    return this.tx(() => {
      const slot = this.slots(date, { forAdmin: byAdmin }).find((sl) => sl.start === start);
      if (!slot) throw new ConflictError('Sorry, that time slot is no longer available. Please choose another.');
      const same = this.db
        .prepare("SELECT 1 FROM appointments WHERE date = ? AND phone = ? AND status = 'booked'")
        .get(date, phone);
      if (same && !byAdmin) throw new ConflictError('This phone number already has an appointment on that day.');
      const ref = this.newRef();
      this.db
        .prepare(`INSERT INTO appointments (ref, date, start_min, end_min, patient_name, phone, email, reason, booked_by)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
        .run(ref, date, slot.start, slot.end, name, phone, email, reason, byAdmin ? 'admin' : 'patient');
      return this.findByRef(ref);
    });
  }

  newRef() {
    for (;;) {
      let ref = '';
      for (let i = 0; i < 6; i++) ref += REF_ALPHABET[randomInt(REF_ALPHABET.length)];
      if (!this.db.prepare('SELECT 1 FROM appointments WHERE ref = ?').get(ref)) return ref;
    }
  }

  findByRef(ref) {
    const a = this.db.prepare('SELECT * FROM appointments WHERE ref = ?').get(String(ref ?? '').trim().toUpperCase());
    return a ? publicAppointment(a) : null;
  }

  /** Patient lookup needs both the reference and the phone number used to book. */
  lookup(ref, phone) {
    const a = this.findByRef(ref);
    if (!a || a.phone !== normalizePhone(phone)) throw new NotFoundError('No appointment found for that reference and phone number.');
    return a;
  }

  cancelByPatient(ref, phone) {
    const a = this.lookup(ref, phone);
    if (a.status !== 'booked') throw new ConflictError('This appointment is not active.');
    const now = this.today();
    const start = fromHHMM(a.start);
    if (a.date < now.date || (a.date === now.date && start <= now.minutes)) throw new ConflictError('This appointment has already started.');
    this.db.prepare("UPDATE appointments SET status = 'cancelled' WHERE id = ?").run(a.id);
    return this.findByRef(a.ref);
  }

  listAppointments({ from, to, status } = {}) {
    assertDate(from);
    assertDate(to);
    const rows = status
      ? this.db.prepare('SELECT * FROM appointments WHERE date BETWEEN ? AND ? AND status = ? ORDER BY date, start_min').all(from, to, status)
      : this.db.prepare('SELECT * FROM appointments WHERE date BETWEEN ? AND ? ORDER BY date, start_min, status').all(from, to);
    return rows.map(publicAppointment);
  }

  setStatus(id, status) {
    if (!STATUSES.includes(status)) throw new ValidationError('Unknown status');
    const a = this.db.prepare('SELECT * FROM appointments WHERE id = ?').get(Number(id));
    if (!a) throw new NotFoundError('Appointment not found');
    if (a.status === 'cancelled' && status !== 'cancelled') {
      // Re-activating: the slot may have been taken meanwhile.
      const clash = this.db
        .prepare("SELECT 1 FROM appointments WHERE date = ? AND status != 'cancelled' AND start_min < ? AND ? < end_min")
        .get(a.date, a.end_min, a.start_min);
      if (clash) throw new ConflictError('That time is now taken by another appointment.');
    }
    this.db.prepare('UPDATE appointments SET status = ? WHERE id = ?').run(status, a.id);
    return publicAppointment(this.db.prepare('SELECT * FROM appointments WHERE id = ?').get(a.id));
  }

  // ---------- admin auth ----------

  /** Sets the first admin password if none exists. Returns the password it set, or null. */
  ensureAdminPassword(initial) {
    const row = this.db.prepare("SELECT value FROM settings WHERE key = 'admin_hash'").get();
    if (row) return null;
    const pw = initial || randomBytes(9).toString('base64url');
    this.db.prepare("INSERT INTO settings (key, value) VALUES ('admin_hash', ?)").run(hashPassword(pw));
    return pw;
  }

  checkPassword(pw) {
    const row = this.db.prepare("SELECT value FROM settings WHERE key = 'admin_hash'").get();
    return typeof pw === 'string' && !!row && verifyPassword(pw, row.value);
  }

  changePassword(current, next) {
    if (!this.checkPassword(current)) throw new ValidationError('Current password is wrong');
    if (typeof next !== 'string' || next.length < 8 || next.length > 200) throw new ValidationError('New password must be at least 8 characters');
    this.db.prepare("UPDATE settings SET value = ? WHERE key = 'admin_hash'").run(hashPassword(next));
    this.db.prepare('DELETE FROM sessions').run();
  }

  createSession() {
    const token = randomBytes(32).toString('base64url');
    const nowMs = this.now().getTime();
    this.db.prepare('DELETE FROM sessions WHERE expires_at < ?').run(nowMs);
    this.db.prepare('INSERT INTO sessions (token, expires_at) VALUES (?, ?)').run(token, nowMs + SESSION_MS);
    return token;
  }

  isValidSession(token) {
    if (!token) return false;
    const row = this.db.prepare('SELECT expires_at FROM sessions WHERE token = ?').get(token);
    return !!row && row.expires_at > this.now().getTime();
  }

  endSession(token) {
    this.db.prepare('DELETE FROM sessions WHERE token = ?').run(token ?? '');
  }

  // ---------- helpers ----------

  tx(fn) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const out = fn();
      this.db.exec('COMMIT');
      return out;
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }
}

function assertDate(d) {
  if (!isValidDate(d)) throw new ValidationError('Invalid date (use YYYY-MM-DD)');
}
