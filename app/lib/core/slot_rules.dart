import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:meta/meta.dart';

/// A time range within one day, in minutes since midnight (end exclusive).
@immutable
final class TimeRange {
  const TimeRange(this.start, this.end);

  /// Parses {start: 'HH:MM', end: 'HH:MM'}; null when malformed.
  static TimeRange? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final s = minutesFromHhmm(raw['start']);
    final e = minutesFromHhmm(raw['end']);
    return s == null || e == null ? null : TimeRange(s, e);
  }

  final int start;
  final int end;

  String get startHhmm => hhmm(start);
  String get endHhmm => hhmm(end);
  Map<String, String> toMap() => {'start': startHhmm, 'end': endHhmm};

  bool overlaps(TimeRange other) => start < other.end && other.start < end;

  @override
  bool operator ==(Object other) => other is TimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$startHhmm–$endHhmm';
}

/// 'HH:MM' (00:00–24:00) → minutes, or null.
int? minutesFromHhmm(Object? s) {
  if (s == '24:00') return 1440;
  final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(s is String ? s : '');
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// The slots a person may book now — same rule as the server (functions/src/core/schedule.js):
/// not in the past, not before the minimum notice (patients), not beyond the booking window
/// (patients), and not overlapping a taken appointment.
List<TimeRange> bookableSlots({
  required ClinicDate date,
  required List<TimeRange> slots,
  required List<TimeRange> taken,
  required ClinicNow now,
  required int minNoticeMinutes,
  required int bookingWindowDays,
  bool forAdmin = false,
}) {
  final offset = daysBetween(now.date, date);
  if (offset < 0) return const [];
  if (!forAdmin && offset > bookingWindowDays) return const [];
  final earliest = now.minutes + (forAdmin ? 0 : minNoticeMinutes) - offset * 1440;
  return [
    for (final s in slots)
      if (s.start >= earliest && !taken.any(s.overlaps)) s,
  ];
}

/// Slot starts every [slotMinutes] between [from] and [to] (minutes), for the slot picker.
List<int> slotGrid(int from, int to, int slotMinutes) {
  if (slotMinutes <= 0) return const [];
  return [for (var t = from; t + slotMinutes <= to && t + slotMinutes <= 1440; t += slotMinutes) t];
}

/// Part of the day a slot belongs to, for grouping the time buttons.
enum DayPart { morning, afternoon, evening }

DayPart dayPartOf(int minutes) => minutes < 12 * 60
    ? DayPart.morning
    : minutes < 17 * 60
    ? DayPart.afternoon
    : DayPart.evening;
