import 'package:meta/meta.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A calendar date in the clinic's time zone, as 'YYYY-MM-DD'.
typedef ClinicDate = String;

/// "Now" expressed in clinic time: the date and minutes since midnight.
@immutable
final class ClinicNow {
  const ClinicNow(this.date, this.minutes);

  final ClinicDate date;
  final int minutes;

  @override
  bool operator ==(Object other) => other is ClinicNow && other.date == date && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(date, minutes);
}

bool _tzReady = false;

/// Converts an instant into clinic time. Unknown zones fall back to UTC.
ClinicNow clinicNow(DateTime instant, String timeZone) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  final location = tz.timeZoneDatabase.locations[timeZone] ?? tz.UTC;
  final local = tz.TZDateTime.from(instant, location);
  return ClinicNow(dateKey(local.year, local.month, local.day), local.hour * 60 + local.minute);
}

ClinicDate dateKey(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

DateTime _utcDate(ClinicDate date) =>
    DateTime.utc(int.parse(date.substring(0, 4)), int.parse(date.substring(5, 7)), int.parse(date.substring(8, 10)));

ClinicDate addDays(ClinicDate date, int days) {
  final d = _utcDate(date).add(Duration(days: days));
  return dateKey(d.year, d.month, d.day);
}

int daysBetween(ClinicDate from, ClinicDate to) => _utcDate(to).difference(_utcDate(from)).inDays;

/// 1 = Monday … 7 = Sunday (DateTime convention).
int weekdayOf(ClinicDate date) => _utcDate(date).weekday;

/// The calendar day as a UTC DateTime, for formatting with intl.
DateTime calendarDay(ClinicDate date) => _utcDate(date);

bool isValidDateKey(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final d = _utcDate(s);
  return dateKey(d.year, d.month, d.day) == s;
}
