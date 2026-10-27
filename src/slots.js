// Pure slot logic: no database, no clock.
import { fromHHMM, toHHMM } from './time.js';

export class ValidationError extends Error {}

/**
 * Validates opening hours sent by the admin, e.g. [{start:'10:00', end:'13:00'}].
 * Returns [[startMin, endMin], ...] sorted, non-overlapping. An empty list means closed.
 */
export function parseIntervals(list) {
  if (!Array.isArray(list)) throw new ValidationError('Hours must be a list');
  if (list.length > 12) throw new ValidationError('Too many time ranges in one day');
  const out = list.map((item, i) => {
    const start = fromHHMM(item?.start);
    const end = fromHHMM(item?.end);
    if (start === null || end === null) throw new ValidationError(`Range ${i + 1}: use HH:MM times`);
    if (end <= start) throw new ValidationError(`Range ${i + 1}: end must be after start`);
    return [start, end];
  });
  out.sort((a, b) => a[0] - b[0]);
  for (let i = 1; i < out.length; i++) {
    if (out[i][0] < out[i - 1][1]) {
      throw new ValidationError(
        `Ranges ${toHHMM(out[i - 1][0])}–${toHHMM(out[i - 1][1])} and ${toHHMM(out[i][0])}–${toHHMM(out[i][1])} overlap`,
      );
    }
  }
  return out;
}

export function formatIntervals(intervals) {
  return intervals.map(([s, e]) => ({ start: toHHMM(s), end: toHHMM(e) }));
}

/** Cuts each opening range into back-to-back slots; a leftover shorter than a slot is dropped. */
export function buildSlots(intervals, slotMinutes) {
  const slots = [];
  for (const [start, end] of intervals) {
    for (let t = start; t + slotMinutes <= end; t += slotMinutes) {
      slots.push({ start: t, end: t + slotMinutes });
    }
  }
  return slots;
}

/**
 * Slots that are not taken and start at or after `earliestStart` (minutes; may be
 * negative for "no limit" or above 1440 for "nothing today").
 * `taken` holds existing appointments as {start_min, end_min}; any overlap blocks a slot,
 * so appointments booked under an older slot length still block correctly.
 */
export function freeSlots({ intervals, slotMinutes, taken = [], earliestStart = -Infinity }) {
  return buildSlots(intervals, slotMinutes).filter(
    (s) => s.start >= earliestStart && !taken.some((b) => s.start < b.end_min && b.start_min < s.end),
  );
}

export function isInsideHours(intervals, start, end) {
  return intervals.some(([s, e]) => start >= s && end <= e);
}
