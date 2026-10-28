import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/core/validators.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/busy_button.dart';
import 'package:clinic_schedule/widgets/form_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

/// Free times on one date for the clinic (no booking window / notice limits).
final StreamProviderFamily<List<TimeRange>, ClinicDate> adminFreeSlotsProvider = StreamProvider.autoDispose
    .family<List<TimeRange>, ClinicDate>((ref, date) {
      final settings = ref.watch(settingsProvider).value ?? ClinicSettings.fallback;
      return ref.watch(clinicRepositoryProvider).watchDays(date, date).map((days) {
        final day = days[date];
        final now = ref.read(clinicNowProvider).value;
        if (day == null || now == null) return const <TimeRange>[];
        return bookableSlots(
          date: date,
          slots: day.slots,
          taken: day.taken,
          now: now,
          minNoticeMinutes: settings.minNoticeMinutes,
          bookingWindowDays: settings.bookingWindowDays,
          forAdmin: true,
        );
      });
    });

/// Book for a patient (e.g. a phone call). The patient can later add it to their account
/// with the reference and phone number.
class NewAppointmentSheet extends ConsumerStatefulWidget {
  const NewAppointmentSheet({super.key});

  @override
  ConsumerState<NewAppointmentSheet> createState() => _NewAppointmentSheetState();
}

class _NewAppointmentSheetState extends ConsumerState<NewAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _reason = TextEditingController();
  ClinicDate? _date;
  int? _start;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(ClinicDate today) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: calendarDay(today),
      lastDate: calendarDay(addDays(today, 365)),
      initialDate: calendarDay(_date ?? today),
    );
    if (picked == null) return;
    setState(() {
      _date = dateKey(picked.year, picked.month, picked.day);
      _start = null;
    });
  }

  Future<void> _submit() async {
    final date = _date;
    final start = _start;
    if (!(_formKey.currentState?.validate() ?? false) || date == null || start == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(appointmentRepositoryProvider)
        .adminBook(
          date: date,
          start: start,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          reason: _reason.text.trim(),
        );
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adminBooked(value.patientName, value.ref))));
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = ref.watch(clinicNowProvider).value?.date;
    final date = _date ?? today;
    final slots = date == null
        ? const <TimeRange>[]
        : ref.watch(adminFreeSlotsProvider(date)).value ?? const <TimeRange>[];
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(l.newAppointment, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(date == null ? l.chooseDay : longDate(context, date)),
              onPressed: today == null ? null : () => _pickDate(today),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: slots.any((s) => s.start == _start) ? _start : null,
              decoration: InputDecoration(labelText: l.freeTime),
              items: [
                for (final s in slots)
                  DropdownMenuItem(value: s.start, child: Text(timeRangeLabel(context, s.start, s.end))),
              ],
              onChanged: (v) => setState(() => _start = v),
              validator: (v) => v == null ? (slots.isEmpty ? l.noTimesLeft : l.chooseTime) : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.patientName),
              validator: (v) => Validators.name(v ?? '') ? null : l.errorName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: l.phone),
              keyboardType: TextInputType.phone,
              validator: (v) => Validators.phone(v ?? '') ? null : l.errorPhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: l.emailOptional),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => Validators.optionalEmail(v ?? '') ? null : l.errorEmail,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: InputDecoration(labelText: l.reasonOptional),
              maxLength: 500,
            ),
            FormMessage(error: _error),
            const SizedBox(height: 12),
            BusyButton(label: l.book, busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
