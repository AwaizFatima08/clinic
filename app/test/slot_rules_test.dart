import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/core/validators.dart';
import 'package:clinic_schedule/features/admin/pick_slots_tab.dart';
import 'package:flutter_test/flutter_test.dart';

// Same cases as functions/test/schedule.test.js, so app and server agree.
List<TimeRange> wednesdaySlots() => [
  for (var t = 600; t + 20 <= 780; t += 20) TimeRange(t, t + 20),
  for (var t = 1020; t + 20 <= 1200; t += 20) TimeRange(t, t + 20),
];

List<TimeRange> bookable(
  ClinicDate date,
  List<TimeRange> slots,
  ClinicNow now, {
  List<TimeRange> taken = const [],
  bool admin = false,
  int notice = 60,
}) => bookableSlots(
  date: date,
  slots: slots,
  taken: taken,
  now: now,
  minNoticeMinutes: notice,
  bookingWindowDays: 30,
  forAdmin: admin,
);

void main() {
  group('bookableSlots', () {
    final slots = wednesdaySlots();

    test('applies minimum notice for patients, not for the clinic', () {
      const now = ClinicNow('2026-11-04', 630); // 10:30
      expect(bookable('2026-11-04', slots, now).first.start, 700); // 11:40
      expect(bookable('2026-11-04', slots, now, admin: true).first.start, 640);
    });

    test('skips taken times, including appointments of an older slot length', () {
      const now = ClinicNow('2026-11-04', 0);
      final free = bookable('2026-11-04', slots, now, taken: const [TimeRange(610, 630)], notice: 0);
      expect(free.map((s) => s.start).take(2), [640, 660]);
    });

    test('no past days and nothing beyond the booking window', () {
      const now = ClinicNow('2026-11-04', 0);
      expect(bookable('2026-11-03', slots, now), isEmpty);
      expect(bookable('2026-12-31', slots, now), isEmpty);
      expect(bookable('2026-12-31', slots, now, admin: true), isNotEmpty);
    });

    test('notice spills over midnight', () {
      const now = ClinicNow('2026-11-04', 720);
      expect(bookable('2026-11-05', slots, now, notice: 1440).first.start, 720);
    });
  });

  test('clinic time conversion (Asia/Karachi is UTC+5)', () {
    expect(clinicNow(DateTime.utc(2026, 11, 4, 20, 30), 'Asia/Karachi'), const ClinicNow('2026-11-05', 90));
    expect(clinicNow(DateTime.utc(2026, 7, 1, 9), 'Europe/London'), const ClinicNow('2026-07-01', 600));
  });

  test('date helpers', () {
    expect(addDays('2026-12-31', 1), '2027-01-01');
    expect(daysBetween('2026-11-04', '2026-11-08'), 4);
    expect(weekdayOf('2026-11-02'), DateTime.monday);
    expect(isValidDateKey('2026-02-30'), isFalse);
  });

  test('HH:MM parsing and the picker grid', () {
    expect(minutesFromHhmm('09:05'), 545);
    expect(minutesFromHhmm('24:00'), 1440);
    expect(minutesFromHhmm('9:05'), isNull);
    expect(hhmm(545), '09:05');
    expect(slotGrid(600, 700, 30), [600, 630, 660]);
    expect(dayPartOf(11 * 60 + 59), DayPart.morning);
    expect(dayPartOf(17 * 60), DayPart.evening);
  });

  test('Pick slots: dates matching chosen weekdays', () {
    // 2–8 Nov 2026 is Monday–Sunday.
    expect(datesMatching('2026-11-02', '2026-11-08', {DateTime.monday, DateTime.thursday}), [
      '2026-11-02',
      '2026-11-05',
    ]);
    expect(datesMatching('2026-11-08', '2026-11-02', {1, 2, 3, 4, 5, 6, 7}), isEmpty);
  });

  test('validators match the server rules', () {
    expect(Validators.phone('+92 300-123 4567'), isTrue);
    expect(Validators.phone('abc'), isFalse);
    expect(Validators.email('a@b.co'), isTrue);
    expect(Validators.optionalEmail(''), isTrue);
    expect(Validators.bookingRef('k7q2mx'), isTrue);
    expect(Validators.bookingRef('K7Q2M0'), isFalse);
    expect(Validators.password('1234567'), isFalse);
  });
}
