import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Booked appointments that no longer fit the opening hours (refreshed after each change).
final FutureProvider<List<Appointment>> outsideHoursProvider = FutureProvider.autoDispose<List<Appointment>>((
  ref,
) async {
  final r = await ref.watch(clinicRepositoryProvider).outsideHours();
  return switch (r) {
    Ok(:final value) => value,
    Err() => const <Appointment>[],
  };
});

/// Date range and status filter on the admin appointments list.
final class AppointmentFilter {
  const AppointmentFilter({required this.from, required this.to, this.status});

  final ClinicDate from;
  final ClinicDate to;
  final AppointmentStatus? status;
}

class AppointmentFilterNotifier extends Notifier<AppointmentFilter?> {
  @override
  AppointmentFilter? build() {
    final today = ref.watch(clinicNowProvider.select((n) => n.value?.date));
    return today == null ? null : AppointmentFilter(from: today, to: addDays(today, 6));
  }

  void setRange(ClinicDate from, ClinicDate to) {
    final s = state;
    if (s != null) state = AppointmentFilter(from: from, to: to.compareTo(from) < 0 ? from : to, status: s.status);
  }

  void setStatus(AppointmentStatus? status) {
    final s = state;
    if (s != null) state = AppointmentFilter(from: s.from, to: s.to, status: status);
  }
}

final NotifierProvider<AppointmentFilterNotifier, AppointmentFilter?> appointmentFilterProvider =
    NotifierProvider.autoDispose<AppointmentFilterNotifier, AppointmentFilter?>(
      AppointmentFilterNotifier.new,
    );

final StreamProvider<List<Appointment>> adminAppointmentsProvider = StreamProvider.autoDispose<List<Appointment>>((
  ref,
) {
  final f = ref.watch(appointmentFilterProvider);
  if (f == null) return const Stream.empty();
  return ref.watch(appointmentRepositoryProvider).watchRange(f.from, f.to);
});

/// Derived: the list after the status filter.
final Provider<AsyncValue<List<Appointment>>> filteredAppointmentsProvider =
    Provider.autoDispose<AsyncValue<List<Appointment>>>((ref) {
      final status = ref.watch(appointmentFilterProvider)?.status;
      return ref
          .watch(adminAppointmentsProvider)
          .whenData((all) => status == null ? all : all.where((a) => a.status == status).toList());
    });
