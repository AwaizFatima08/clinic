import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/admin/admin_providers.dart';
import 'package:clinic_schedule/features/admin/new_appointment_sheet.dart';
import 'package:clinic_schedule/features/admin/outside_hours_banner.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/confirm_dialog.dart';
import 'package:clinic_schedule/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminAppointmentsScreen extends ConsumerWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(filteredAppointmentsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const NewAppointmentSheet(),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.newAppointment),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 96),
        children: [
          const OutsideHoursBanner(),
          const _FilterBar(),
          const SizedBox(height: 8),
          ...list.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (_, _) => [Text(l.loadError)],
            data: (items) => items.isEmpty
                ? [Padding(padding: const EdgeInsets.all(16), child: Text(l.noAppointmentsInRange))]
                : [for (final a in items) _AdminAppointmentCard(a)],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  Future<void> _pickRange(BuildContext context, WidgetRef ref, AppointmentFilter f) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(2025),
      lastDate: DateTime.utc(2035),
      initialDateRange: DateTimeRange(start: calendarDay(f.from), end: calendarDay(f.to)),
    );
    if (picked == null) return;
    ref
        .read(appointmentFilterProvider.notifier)
        .setRange(
          dateKey(picked.start.year, picked.start.month, picked.start.day),
          dateKey(picked.end.year, picked.end.month, picked.end.day),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final f = ref.watch(appointmentFilterProvider);
    final today = ref.watch(clinicNowProvider).value?.date;
    if (f == null || today == null) return const SizedBox.shrink();
    final notifier = ref.read(appointmentFilterProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(
            f.from == f.to ? longDate(context, f.from) : '${longDate(context, f.from)} – ${longDate(context, f.to)}',
          ),
          onPressed: () => _pickRange(context, ref, f),
        ),
        ActionChip(label: Text(l.today), onPressed: () => notifier.setRange(today, today)),
        ActionChip(label: Text(l.next7Days), onPressed: () => notifier.setRange(today, addDays(today, 6))),
        DropdownButton<AppointmentStatus?>(
          value: f.status,
          onChanged: notifier.setStatus,
          items: [
            DropdownMenuItem(child: Text(l.allStatuses)),
            for (final s in AppointmentStatus.values)
              DropdownMenuItem(
                value: s,
                child: StatusBadge(status: s),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdminAppointmentCard extends ConsumerWidget {
  const _AdminAppointmentCard(this.a);

  final Appointment a;

  Future<void> _set(BuildContext context, WidgetRef ref, AppointmentStatus status, {String? question}) async {
    if (question != null && !await confirmAction(context, question)) return;
    final result = await ref.read(appointmentRepositoryProvider).setStatus(a.ref, status);
    if (!context.mounted) return;
    if (result case Err(:final failure)) showMessage(context, failure.message, error: true);
    ref.invalidate(outsideHoursProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(status: a.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${longDate(context, a.date)} · ${timeRangeLabel(context, a.start, a.end)}',
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(a.patientName, style: text.titleMedium),
            SelectableText('${a.phone}${a.email.isEmpty ? '' : ' · ${a.email}'}'),
            Text(
              [
                l.refLabel(a.ref),
                if (a.bookedByClinic) l.byClinic,
                if (a.patientUid != null) l.hasAccount,
                if (a.cancelledBy != null) l.cancelledBy(a.cancelledBy!),
              ].join(' · '),
              style: text.bodySmall,
            ),
            if (a.reason.isNotEmpty) Padding(padding: const EdgeInsetsDirectional.only(top: 4), child: Text(a.reason)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: a.status == AppointmentStatus.booked
                  ? [
                      OutlinedButton(
                        onPressed: () => _set(context, ref, AppointmentStatus.completed),
                        child: Text(l.markDone),
                      ),
                      OutlinedButton(
                        onPressed: () => _set(context, ref, AppointmentStatus.noShow),
                        child: Text(l.markMissed),
                      ),
                      TextButton(
                        onPressed: () => _set(
                          context,
                          ref,
                          AppointmentStatus.cancelled,
                          question: l.adminCancelQuestion(a.patientName),
                        ),
                        child: Text(l.cancel),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: () => _set(context, ref, AppointmentStatus.booked),
                        child: Text(l.setBackToBooked),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
