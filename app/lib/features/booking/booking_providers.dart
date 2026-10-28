import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public day documents for today … end of the booking window.
final StreamProvider<Map<String, ClinicDay>> bookingDaysProvider = StreamProvider.autoDispose<Map<String, ClinicDay>>((
  ref,
) {
  final today = ref.watch(clinicNowProvider.select((n) => n.value?.date));
  final window = ref.watch(settingsProvider.select((s) => s.value?.bookingWindowDays));
  if (today == null || window == null) return const Stream.empty();
  return ref.watch(clinicRepositoryProvider).watchDays(today, addDays(today, window));
});

/// One entry per date in the window, with its free slots right now.
final class BookableDay {
  const BookableDay(this.date, {required this.open, required this.free});

  final ClinicDate date;
  final bool open;
  final List<TimeRange> free;
}

/// Derived from settings, the clock and the day documents (never stored).
final Provider<List<BookableDay>?> bookableDaysProvider = Provider.autoDispose<List<BookableDay>?>((ref) {
  final settings = ref.watch(settingsProvider).value;
  final now = ref.watch(clinicNowProvider).value;
  final days = ref.watch(bookingDaysProvider).value;
  if (settings == null || now == null || days == null) return null;
  return [
    for (var i = 0; i <= settings.bookingWindowDays; i++)
      () {
        final date = addDays(now.date, i);
        final day = days[date];
        final free = day == null || !day.open
            ? const <TimeRange>[]
            : bookableSlots(
                date: date,
                slots: day.slots,
                taken: day.taken,
                now: now,
                minNoticeMinutes: settings.minNoticeMinutes,
                bookingWindowDays: settings.bookingWindowDays,
              );
        return BookableDay(date, open: day?.open ?? false, free: free);
      }(),
  ];
});

/// The patient's choices on the booking screen.
final class BookingState {
  const BookingState({this.date, this.start, this.busy = false, this.error, this.booked});

  final ClinicDate? date;
  final int? start;
  final bool busy;
  final String? error;
  final Appointment? booked;

  BookingState copyWith({ClinicDate? date, int? start, bool clearStart = false}) =>
      BookingState(date: date ?? this.date, start: clearStart ? null : start ?? this.start);
}

class BookingNotifier extends Notifier<BookingState> {
  @override
  BookingState build() => const BookingState();

  void selectDate(ClinicDate date) => state = BookingState(date: date);

  void selectSlot(int start) => state = state.copyWith(start: start);

  void reset() => state = const BookingState();

  Future<void> confirm(String reason) async {
    final date = state.date;
    final start = state.start;
    if (date == null || start == null || state.busy) return;
    state = BookingState(date: date, start: start, busy: true);
    final result = await ref.read(appointmentRepositoryProvider).book(date, start, reason);
    if (!ref.mounted) return;
    state = switch (result) {
      Ok(:final value) => BookingState(booked: value),
      // A taken slot: keep the day, drop the time so the patient picks again.
      Err(:final failure) when failure.code == FailureCode.conflict => BookingState(date: date, error: failure.message),
      Err(:final failure) => BookingState(date: date, start: start, error: failure.message),
    };
  }
}

final NotifierProvider<BookingNotifier, BookingState> bookingProvider =
    NotifierProvider.autoDispose<BookingNotifier, BookingState>(BookingNotifier.new);
