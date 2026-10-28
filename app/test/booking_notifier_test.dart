import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/api_service.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/data/repositories.dart';
import 'package:clinic_schedule/features/booking/booking_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeApi implements ClinicApi {
  _FakeApi(this.reply);

  Result<Map<String, Object?>> reply;
  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<Result<Map<String, Object?>>> call(String op, [Map<String, Object?> data = const {}]) async {
    calls.add((op, data));
    return reply;
  }
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

ProviderContainer _containerWith(_FakeApi api) => ProviderContainer.test(
  overrides: [appointmentRepositoryProvider.overrideWithValue(AppointmentRepository(_MockFirestore(), api))],
);

void main() {
  test('confirm books through the api and shows the reference', () async {
    final api = _FakeApi(
      const Ok({'ref': 'K7Q2MX', 'date': '2026-11-05', 'start': '10:00', 'end': '10:20', 'status': 'booked'}),
    );
    final c = _containerWith(api);
    final n = c.read(bookingProvider.notifier)
      ..selectDate('2026-11-05')
      ..selectSlot(600);
    await n.confirm('  Fever  ');
    final (op, data) = api.calls.single;
    expect(op, 'book');
    expect(data, {'date': '2026-11-05', 'start': '10:00', 'reason': 'Fever'});
    expect(c.read(bookingProvider).booked?.ref, 'K7Q2MX');
    expect(c.read(bookingProvider).booked?.status, AppointmentStatus.booked);
  });

  test('a slot taken meanwhile keeps the day but asks for another time', () async {
    final api = _FakeApi(const Err(Failure(FailureCode.conflict, 'Sorry, that time slot is no longer available.')));
    final c = _containerWith(api);
    final n = c.read(bookingProvider.notifier)
      ..selectDate('2026-11-05')
      ..selectSlot(600);
    await n.confirm('');
    final s = c.read(bookingProvider);
    expect(s.date, '2026-11-05');
    expect(s.start, isNull);
    expect(s.error, contains('no longer available'));
  });

  test('other errors keep the chosen time so the patient can retry', () async {
    final c = _containerWith(_FakeApi(const Err(Failure(FailureCode.network, 'No connection.'))));
    final n = c.read(bookingProvider.notifier)
      ..selectDate('2026-11-05')
      ..selectSlot(600);
    await n.confirm('');
    expect(c.read(bookingProvider).start, 600);
    expect(c.read(bookingProvider).error, 'No connection.');
  });

  test('nothing is sent without a chosen time', () async {
    final api = _FakeApi(const Ok({}));
    final c = _containerWith(api);
    c.read(bookingProvider.notifier).selectDate('2026-11-05');
    await c.read(bookingProvider.notifier).confirm('');
    expect(api.calls, isEmpty);
  });
}
