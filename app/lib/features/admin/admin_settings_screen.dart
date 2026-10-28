import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/core/validators.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/account/delete_account_card.dart';
import 'package:clinic_schedule/features/admin/admin_providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/busy_button.dart';
import 'package:clinic_schedule/widgets/form_message.dart';
import 'package:clinic_schedule/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final FutureProvider<ClinicSettings> _adminSettingsProvider = FutureProvider.autoDispose<ClinicSettings>(
  (ref) => ref.watch(clinicRepositoryProvider).loadAdminSettings(),
);

const _slotChoices = [10, 15, 20, 25, 30, 40, 45, 60, 90, 120];

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ref
        .watch(_adminSettingsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l.loadError)),
          data: (s) => ListView(
            padding: const EdgeInsetsDirectional.all(16),
            children: [
              _SettingsForm(initial: s),
              const _TestEmailCard(),
              const DeleteAccountCard(admin: true),
            ],
          ),
        );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});

  final ClinicSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _clinicName = TextEditingController(text: widget.initial.clinicName);
  late final _doctorName = TextEditingController(text: widget.initial.doctorName);
  late final _window = TextEditingController(text: '${widget.initial.bookingWindowDays}');
  late final _notice = TextEditingController(text: '${widget.initial.minNoticeMinutes}');
  late final _maxUpcoming = TextEditingController(text: '${widget.initial.maxUpcomingPerPatient}');
  late final _adminEmail = TextEditingController(text: widget.initial.adminEmail);
  late final _timezone = TextEditingController(text: widget.initial.timezone);
  late final _instructions = TextEditingController(text: widget.initial.instructions);
  late int _slotMinutes = widget.initial.slotMinutes;
  late ScheduleMode _mode = widget.initial.scheduleMode;
  late bool _requireLogin = widget.initial.requireLogin;
  late bool _email = widget.initial.emailNotifications;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_clinicName, _doctorName, _window, _notice, _maxUpcoming, _adminEmail, _timezone, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final settings = ClinicSettings(
      clinicName: _clinicName.text.trim(),
      doctorName: _doctorName.text.trim(),
      slotMinutes: _slotMinutes,
      timezone: _timezone.text.trim(),
      bookingWindowDays: int.parse(_window.text),
      minNoticeMinutes: int.parse(_notice.text),
      scheduleMode: _mode,
      requireLogin: _requireLogin,
      maxUpcomingPerPatient: int.parse(_maxUpcoming.text),
      emailNotifications: _email,
      instructions: _instructions.text.trim(),
      adminEmail: _adminEmail.text.trim(),
    );
    final result = await ref.read(clinicRepositoryProvider).saveSettings(settings);
    if (!mounted) return;
    ref.invalidate(outsideHoursProvider);
    setState(() {
      _busy = false;
      switch (result) {
        case Ok(:final value):
          _info = value.isEmpty ? l.saved : l.savedWithOutside(value.length);
        case Err(:final failure):
          _error = failure.message;
      }
    });
  }

  String? Function(String?) _intIn(int min, int max) {
    final l = AppLocalizations.of(context);
    return (v) {
      final n = int.tryParse(v ?? '');
      return n != null && n >= min && n <= max ? null : l.errorNumberRange(min, max);
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const gap = SizedBox(height: 12);
    final slotItems = {..._slotChoices, _slotMinutes}.toList()..sort();
    return SectionCard(
      title: l.clinicSettings,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _clinicName,
              decoration: InputDecoration(labelText: l.clinicName),
              validator: (v) => (v ?? '').trim().isEmpty ? l.required : null,
            ),
            gap,
            TextFormField(
              controller: _doctorName,
              decoration: InputDecoration(labelText: l.doctorName),
            ),
            gap,
            DropdownButtonFormField<int>(
              initialValue: _slotMinutes,
              decoration: InputDecoration(labelText: l.slotLength, helperText: l.slotLengthHelp),
              items: [for (final m in slotItems) DropdownMenuItem(value: m, child: Text(l.minutes(m)))],
              onChanged: (v) => setState(() => _slotMinutes = v ?? _slotMinutes),
            ),
            gap,
            DropdownButtonFormField<ScheduleMode>(
              initialValue: _mode,
              decoration: InputDecoration(labelText: l.howDaysOpen),
              items: [
                DropdownMenuItem(value: ScheduleMode.weekly, child: Text(l.modeWeekly)),
                DropdownMenuItem(value: ScheduleMode.daily, child: Text(l.modeDaily)),
              ],
              onChanged: (v) => setState(() => _mode = v ?? _mode),
            ),
            gap,
            TextFormField(
              controller: _window,
              decoration: InputDecoration(labelText: l.bookingWindow),
              keyboardType: TextInputType.number,
              validator: _intIn(1, 365),
            ),
            gap,
            TextFormField(
              controller: _notice,
              decoration: InputDecoration(labelText: l.minNotice),
              keyboardType: TextInputType.number,
              validator: _intIn(0, 10080),
            ),
            gap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.requireLogin),
              value: _requireLogin,
              onChanged: (v) => setState(() => _requireLogin = v),
            ),
            TextFormField(
              controller: _maxUpcoming,
              decoration: InputDecoration(labelText: l.maxUpcoming),
              keyboardType: TextInputType.number,
              validator: _intIn(1, 50),
            ),
            gap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.emailNotifications),
              value: _email,
              onChanged: (v) => setState(() => _email = v),
            ),
            TextFormField(
              controller: _adminEmail,
              decoration: InputDecoration(labelText: l.alertEmail),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => Validators.optionalEmail(v ?? '') ? null : l.errorEmail,
            ),
            gap,
            TextFormField(
              controller: _timezone,
              decoration: InputDecoration(labelText: l.timeZone),
              validator: (v) => (v ?? '').trim().isEmpty ? l.required : null,
            ),
            gap,
            TextFormField(
              controller: _instructions,
              decoration: InputDecoration(labelText: l.patientMessage),
              maxLines: 3,
              maxLength: 1000,
            ),
            FormMessage(error: _error, info: _info),
            gap,
            BusyButton(label: l.saveSettings, busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Sends a test email to the signed-in admin and reports whether it went out.
class _TestEmailCard extends ConsumerStatefulWidget {
  const _TestEmailCard();

  @override
  ConsumerState<_TestEmailCard> createState() => _TestEmailCardState();
}

class _TestEmailCardState extends ConsumerState<_TestEmailCard> {
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final queued = await ref.read(clinicRepositoryProvider).sendTestEmail();
    if (!mounted) return;
    switch (queued) {
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      case Ok(value: (final id, final to)):
        await _waitForDelivery(id, to);
    }
  }

  /// The mail function usually answers within a few seconds.
  Future<void> _waitForDelivery(String id, String to) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(clinicRepositoryProvider);
    setState(() => _info = l.sendingTo(to));
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final status = await repo.testEmailStatus(id);
      if (!mounted) return;
      if (status case Ok(value: (final state, final error)) when state != 'pending') {
        setState(() {
          _busy = false;
          _info = state == 'sent' ? l.testEmailSent(to) : null;
          _error = state == 'sent' ? null : l.testEmailFailed(state, error ?? '');
        });
        return;
      }
    }
    setState(() {
      _busy = false;
      _info = null;
      _error = l.testEmailTimeout;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: l.emailCheck,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.emailCheckHelp),
          FormMessage(error: _error, info: _info),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _busy ? null : _send, child: Text(l.sendTestEmail)),
        ],
      ),
    );
  }
}
