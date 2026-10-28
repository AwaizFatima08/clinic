// Pure scheduling rules shared by the Cloud Functions and the web pages.
// Firestore stores times as 'HH:MM' strings; these helpers work in minutes.
import { ValidationError, buildSlots, parseIntervals } from './slots.js';
import { daysBetween, fromHHMM, isValidTimeZone, toHHMM, weekday } from './time.js';

export const DEFAULT_SETTINGS = Object.freeze({
  clinicName: 'My Online Clinic',
  doctorName: 'Dr. Your Name',
  slotMinutes: 20,
  timezone: 'Asia/Karachi',
  bookingWindowDays: 30,
  minNoticeMinutes: 60,
  // 'weekly': the weekly timetable opens days automatically.
  // 'daily':  a day is closed until the admin opens it (hours or picked slots).
  scheduleMode: 'weekly',
  requireLogin: true,
  maxUpcomingPerPatient: 3,
  emailNotifications: true,
  adminEmail: '',
  instructions: 'You will receive the video-call link before your appointment.',
});

const MORNING_EVENING = [{ start: '10:00', end: '13:00' }, { start: '17:00', end: '20:00' }];
// Keys are weekdays, 0 = Sunday.
export const DEFAULT_WEEKLY = Object.freeze({
  0: [], 1: MORNING_EVENING, 2: MORNING_EVENING, 3: MORNING_EVENING, 4: MORNING_EVENING, 5: MORNING_EVENING, 6: MORNING_EVENING,
});

export const STATUSES = ['booked', 'completed', 'no_show', 'cancelled'];

const str = (v, min, max, label) => {
  if (typeof v !== 'string') throw new ValidationError(`${label}: expected text`);
  const s = v.trim();
  if (s.length < min || s.length > max) throw new ValidationError(`${label}: must be ${min}–${max} characters`);
  return s;
};
const int = (v, min, max, label) => {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new ValidationError(`${label}: whole number from ${min} to ${max}`);
  return n;
};
const bool = (v, label) => {
  if (typeof v !== 'boolean') throw new ValidationError(`${label}: expected yes/no`);
  return v;
};

const SETTING_RULES = {
  clinicName: (v) => str(v, 1, 80, 'Clinic name'),
  doctorName: (v) => str(v, 0, 80, 'Doctor name'),
  slotMinutes: (v) => int(v, 5, 240, 'Slot length'),
  timezone: (v) => {
    if (!isValidTimeZone(v)) throw new ValidationError('Unknown time zone');
    return v;
  },
  bookingWindowDays: (v) => int(v, 1, 365, 'Booking window'),
  minNoticeMinutes: (v) => int(v, 0, 10080, 'Minimum notice'),
  scheduleMode: (v) => {
    if (v !== 'weekly' && v !== 'daily') throw new ValidationError('Schedule mode must be weekly or daily');
    return v;
  },
  requireLogin: (v) => bool(v, 'Require login'),
  maxUpcomingPerPatient: (v) => int(v, 1, 50, 'Upcoming appointments per patient'),
  emailNotifications: (v) => bool(v, 'Email notifications'),
  adminEmail: (v) => {
    const s = str(v, 0, 120, 'Admin email');
    if (s && !isEmail(s)) throw new ValidationError('Admin email is not valid');
    return s;
  },
  instructions: (v) => str(v, 0, 1000, 'Patient message'),
};

export function validateSettingsPatch(patch) {
  if (!patch || typeof patch !== 'object') throw new ValidationError('Settings missing');
  const out = {};
  for (const [k, v] of Object.entries(patch)) {
    if (!SETTING_RULES[k]) throw new ValidationError(`Unknown setting: ${k}`);
    out[k] = SETTING_RULES[k](v);
  }
  return out;
}

export function withDefaults(settings) {
  return { ...DEFAULT_SETTINGS, ...(settings ?? {}) };
}

/** Validates a weekly timetable {0..6: [{start,end}]} and returns the same shape, sorted. */
export function validateWeekly(days) {
  const names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const out = {};
  for (let d = 0; d < 7; d++) {
    try {
      out[d] = toStored(parseIntervals(days?.[d] ?? []));
    } catch (e) {
      throw new ValidationError(`${names[d]}: ${e.message}`);
    }
  }
  return out;
}

/**
 * Validates a per-date override.
 *   {mode: 'hours', intervals: [{start,end}]}   ([] = closed)
 *   {mode: 'slots', starts: ['10:00', '10:40']}  (only these slots open)
 */
export function validateOverride(o) {
  if (o?.mode === 'hours') return { mode: 'hours', intervals: toStored(parseIntervals(o.intervals ?? [])) };
  if (o?.mode === 'slots') {
    if (!Array.isArray(o.starts) || o.starts.length > 288) throw new ValidationError('Pick between 0 and 288 slots');
    const mins = o.starts.map((s) => {
      const m = fromHHMM(s);
      if (m === null || m >= 1440) throw new ValidationError(`Bad slot time: ${s}`);
      return m;
    });
    return { mode: 'slots', starts: [...new Set(mins)].sort((a, b) => a - b).map(toHHMM) };
  }
  throw new ValidationError('Override mode must be hours or slots');
}

export function toStored(intervals) {
  return intervals.map(([s, e]) => ({ start: toHHMM(s), end: toHHMM(e) }));
}

export function fromStored(list) {
  return (list ?? []).map((r) => [fromHHMM(r.start), fromHHMM(r.end)]);
}

/** Picked slot starts → non-overlapping slots of the current length. */
export function slotsFromStarts(starts, slotMinutes) {
  const out = [];
  let lastEnd = -1;
  for (const m of (starts ?? []).map(fromHHMM).filter((x) => x !== null).sort((a, b) => a - b)) {
    if (m >= lastEnd && m + slotMinutes <= 1440) {
      out.push({ start: m, end: m + slotMinutes });
      lastEnd = m + slotMinutes;
    }
  }
  return out;
}

/**
 * The bookable grid for one date, before removing taken or past slots.
 * Returns {source, slots: [{start, end}] (minutes), intervals: [[s,e]] (opening hours)}.
 */
export function daySchedule(date, settings, weekly, override) {
  const s = withDefaults(settings);
  if (override?.mode === 'slots') {
    const slots = slotsFromStarts(override.starts, s.slotMinutes);
    return { source: 'slots', slots, intervals: slots.map((x) => [x.start, x.end]) };
  }
  if (override?.mode === 'hours') {
    const intervals = fromStored(override.intervals);
    return { source: 'hours', slots: buildSlots(intervals, s.slotMinutes), intervals };
  }
  if (s.scheduleMode === 'daily') return { source: 'not_activated', slots: [], intervals: [] };
  const intervals = fromStored(weekly?.[weekday(date)] ?? []);
  return { source: 'weekly', slots: buildSlots(intervals, s.slotMinutes), intervals };
}

/**
 * Slots a patient (or the admin) may book now.
 * slots/taken: [{start, end}] in minutes; now: {date, minutes} in clinic time.
 */
export function bookableSlots({ date, slots, taken, now, settings, forAdmin = false }) {
  const s = withDefaults(settings);
  const offset = daysBetween(now.date, date);
  if (offset < 0) return [];
  if (!forAdmin && offset > s.bookingWindowDays) return [];
  const earliest = now.minutes + (forAdmin ? 0 : s.minNoticeMinutes) - offset * 1440;
  return slots.filter((x) => x.start >= earliest && !(taken ?? []).some((t) => x.start < t.end && t.start < x.end));
}

export function isInside(intervals, start, end) {
  return intervals.some(([s, e]) => start >= s && end <= e);
}

// ---------- patient input ----------

export function isEmail(s) {
  return typeof s === 'string' && s.length <= 120 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

export function normalizePhone(p) {
  if (typeof p !== 'string') return '';
  const s = p.replace(/[\s\-().]/g, '');
  return /^\+?\d{7,15}$/.test(s) ? s : '';
}

export function validatePatientDetails(input, { emailRequired = false } = {}) {
  let name;
  try {
    name = str(input?.name, 2, 80, 'Name');
  } catch {
    throw new ValidationError('Please enter the patient name (2–80 characters)');
  }
  const phone = normalizePhone(input?.phone);
  if (!phone) throw new ValidationError('Please enter a valid phone number (7–15 digits, + allowed)');
  const email = typeof input?.email === 'string' ? input.email.trim().toLowerCase() : '';
  if (email ? !isEmail(email) : emailRequired) throw new ValidationError('Please enter a valid email address');
  const reason = typeof input?.reason === 'string' ? input.reason.trim().slice(0, 500) : '';
  return { name, phone, email, reason };
}
