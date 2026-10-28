import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ValidationError, buildSlots, freeSlots, parseIntervals } from '../src/core/slots.js';
import {
  DEFAULT_WEEKLY,
  bookableSlots,
  daySchedule,
  normalizePhone,
  slotsFromStarts,
  validateOverride,
  validatePatientDetails,
  validateSettingsPatch,
  validateWeekly,
  withDefaults,
} from '../src/core/schedule.js';
import { nowInTz, zonedToUtc } from '../src/core/time.js';

const S = withDefaults({});
const starts = (slots) => slots.map((s) => s.start);

test('parseIntervals sorts ranges and rejects overlaps or bad times', () => {
  assert.deepEqual(parseIntervals([{ start: '17:00', end: '20:00' }, { start: '10:00', end: '13:00' }]), [[600, 780], [1020, 1200]]);
  assert.throws(() => parseIntervals([{ start: '10:00', end: '12:00' }, { start: '11:00', end: '13:00' }]), ValidationError);
  assert.throws(() => parseIntervals([{ start: '13:00', end: '10:00' }]), ValidationError);
});

test('buildSlots drops a leftover shorter than one slot; old bookings block overlapping slots', () => {
  assert.deepEqual(starts(buildSlots([[600, 700]], 30)), [600, 630, 660]);
  assert.deepEqual(starts(freeSlots({ intervals: [[600, 720]], slotMinutes: 30, taken: [{ start_min: 620, end_min: 640 }] })), [660, 690]);
});

test('weekly timetable: Wednesday has 18 twenty-minute slots, Sunday is closed', () => {
  assert.equal(daySchedule('2026-11-04', S, DEFAULT_WEEKLY, null).slots.length, 18);
  assert.equal(daySchedule('2026-11-08', S, DEFAULT_WEEKLY, null).slots.length, 0);
  assert.equal(daySchedule('2026-11-04', { ...S, slotMinutes: 30 }, DEFAULT_WEEKLY, null).slots.length, 12);
});

test('override "hours" replaces the weekly hours for that date; [] closes it', () => {
  const d = daySchedule('2026-11-08', S, DEFAULT_WEEKLY, { mode: 'hours', intervals: [{ start: '14:00', end: '15:00' }] });
  assert.equal(d.source, 'hours');
  assert.deepEqual(starts(d.slots), [840, 860, 880]);
  assert.equal(daySchedule('2026-11-04', S, DEFAULT_WEEKLY, { mode: 'hours', intervals: [] }).slots.length, 0);
});

test('override "slots" opens only the picked slots', () => {
  const d = daySchedule('2026-11-04', S, DEFAULT_WEEKLY, { mode: 'slots', starts: ['11:00', '09:00', '11:20'] });
  assert.equal(d.source, 'slots');
  assert.deepEqual(d.slots, [{ start: 540, end: 560 }, { start: 660, end: 680 }, { start: 680, end: 700 }]);
});

test('picked slots never overlap when the slot length grows', () => {
  assert.deepEqual(slotsFromStarts(['10:00', '10:20', '10:40'], 30), [{ start: 600, end: 630 }, { start: 640, end: 670 }]);
  assert.deepEqual(slotsFromStarts(['23:50'], 20), [], 'a slot may not run past midnight');
});

test("'daily' mode: a day without an override is not activated", () => {
  const d = daySchedule('2026-11-04', { ...S, scheduleMode: 'daily' }, DEFAULT_WEEKLY, null);
  assert.equal(d.source, 'not_activated');
  assert.equal(d.slots.length, 0);
});

test('bookableSlots applies minimum notice, booking window and taken times', () => {
  const slots = daySchedule('2026-11-04', S, DEFAULT_WEEKLY, null).slots;
  const now = { date: '2026-11-04', minutes: 630 }; // 10:30
  assert.equal(bookableSlots({ date: '2026-11-04', slots, taken: [], now, settings: S })[0].start, 700, '60 min notice → 11:40');
  assert.equal(bookableSlots({ date: '2026-11-04', slots, taken: [], now, settings: S, forAdmin: true })[0].start, 640);
  const taken = [{ start: 700, end: 720 }];
  assert.equal(bookableSlots({ date: '2026-11-04', slots, taken, now, settings: S })[0].start, 720);
  assert.deepEqual(bookableSlots({ date: '2026-11-03', slots, taken: [], now, settings: S }), [], 'past day');
  assert.deepEqual(bookableSlots({ date: '2026-12-31', slots, taken: [], now, settings: S }), [], 'beyond window');
});

test('minimum notice spills over midnight', () => {
  const s = { ...S, minNoticeMinutes: 1440 };
  const slots = daySchedule('2026-11-05', s, DEFAULT_WEEKLY, null).slots;
  assert.equal(bookableSlots({ date: '2026-11-05', slots, taken: [], now: { date: '2026-11-04', minutes: 720 }, settings: s })[0].start, 720);
});

test('validation of settings, weekly hours, overrides and patient details', () => {
  assert.deepEqual(validateSettingsPatch({ slotMinutes: 30, requireLogin: false }), { slotMinutes: 30, requireLogin: false });
  assert.throws(() => validateSettingsPatch({ slotMinutes: 3 }), ValidationError);
  assert.throws(() => validateSettingsPatch({ nope: 1 }), ValidationError);
  assert.throws(() => validateSettingsPatch({ timezone: 'Mars/Base' }), ValidationError);
  assert.equal(validateWeekly({ 1: [{ start: '09:00', end: '12:00' }] })[1][0].start, '09:00');
  assert.throws(() => validateWeekly({ 2: [{ start: '12:00', end: '09:00' }] }), /Tuesday/);
  assert.deepEqual(validateOverride({ mode: 'slots', starts: ['10:20', '10:00', '10:20'] }), { mode: 'slots', starts: ['10:00', '10:20'] });
  assert.throws(() => validateOverride({ mode: 'slots', starts: ['25:00'] }), ValidationError);
  assert.equal(normalizePhone('+92 300-123 4567'), '+923001234567');
  assert.equal(normalizePhone('abc'), '');
  assert.throws(() => validatePatientDetails({ name: 'A', phone: '+923001234567' }), ValidationError);
  assert.throws(() => validatePatientDetails({ name: 'Ali', phone: '+923001234567', email: 'x@' }), ValidationError);
});

test('clinic time ↔ UTC (Asia/Karachi is UTC+5)', () => {
  assert.equal(zonedToUtc('2026-11-04', 600, 'Asia/Karachi').toISOString(), '2026-11-04T05:00:00.000Z');
  assert.deepEqual(nowInTz('Asia/Karachi', new Date('2026-11-04T20:30:00Z')), { date: '2026-11-05', minutes: 90 });
  // A zone with daylight saving: 10:00 in London on a summer day is 09:00 UTC.
  assert.equal(zonedToUtc('2026-07-01', 600, 'Europe/London').toISOString(), '2026-07-01T09:00:00.000Z');
});
