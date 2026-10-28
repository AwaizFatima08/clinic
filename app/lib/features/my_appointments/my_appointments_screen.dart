import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/core/validators.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/confirm_dialog.dart';
import 'package:clinic_schedule/widgets/section_card.dart';
import 'package:clinic_schedule/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final StreamProvider<List<Appointment>> myAppointmentsProvider = StreamProvider.autoDispose<List<Appointment>>((ref) {
  final uid = ref.watch(authUserProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(appointmentRepositoryProvider).watchMine(uid);
});

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).now();
    return ref
        .watch(myAppointmentsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.loadError)),
          data: (all) {
            final upcoming = all.where((a) => a.isUpcoming(now)).toList().reversed.toList();
            final past = all.where((a) => !a.isUpcoming(now)).toList();
            return ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                SectionCard(
                  title: l.upcomingAppointments,
                  child: upcoming.isEmpty
                      ? Text(l.noUpcoming)
                      : Column(children: [for (final a in upcoming) _AppointmentTile(a, canCancel: true)]),
                ),
                SectionCard(
                  title: l.pastAppointments,
                  child: past.isEmpty
                      ? Text(l.nothingYet)
                      : Column(children: [for (final a in past) _AppointmentTile(a, canCancel: false)]),
                ),
                const _ClaimCard(),
              ],
            );
          },
        );
  }
}

class _AppointmentTile extends ConsumerWidget {
  const _AppointmentTile(this.appointment, {required this.canCancel});

  final Appointment appointment;
  final bool canCancel;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final question = l.cancelQuestion(longDate(context, appointment.date), timeLabel(context, appointment.start));
    if (!await confirmAction(context, question, confirmLabel: l.cancelAppointment)) return;
    final result = await ref.read(appointmentRepositoryProvider).cancelMine(appointment.ref);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showMessage(context, l.cancelled);
      case Err(:final failure):
        showMessage(context, failure.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final a = appointment;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          StatusBadge(status: a.status),
          const SizedBox(width: 8),
          Expanded(child: Text(longDate(context, a.date))),
        ],
      ),
      subtitle: Text(
        '${timeRangeLabel(context, a.start, a.end)}\n${l.refLabel(a.ref)}${a.reason.isEmpty ? '' : ' · ${a.reason}'}',
      ),
      isThreeLine: true,
      trailing: canCancel ? TextButton(onPressed: () => _cancel(context, ref), child: Text(l.cancel)) : null,
    );
  }
}

/// Adds a booking made by phone or on the website without an account.
class _ClaimCard extends ConsumerStatefulWidget {
  const _ClaimCard();

  @override
  ConsumerState<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends ConsumerState<_ClaimCard> {
  final _formKey = GlobalKey<FormState>();
  final _ref = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ref.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final result = await ref.read(appointmentRepositoryProvider).claim(_ref.text, _phone.text);
    if (!mounted) return;
    setState(() => _busy = false);
    final l = AppLocalizations.of(context);
    switch (result) {
      case Ok(:final value):
        _ref.clear();
        _phone.clear();
        showMessage(context, l.claimed(longDate(context, value.date), timeLabel(context, value.start)));
      case Err(:final failure):
        showMessage(context, failure.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: l.claimTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _ref,
              decoration: InputDecoration(labelText: l.bookingReference),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => Validators.bookingRef(v ?? '') ? null : l.errorRef,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: l.phoneUsed),
              keyboardType: TextInputType.phone,
              validator: (v) => Validators.phone(v ?? '') ? null : l.errorPhone,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : _submit, child: Text(l.addToAccount)),
          ],
        ),
      ),
    );
  }
}
