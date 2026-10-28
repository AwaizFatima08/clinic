import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/booking/booking_providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/busy_button.dart';
import 'package:clinic_schedule/widgets/form_message.dart';
import 'package:clinic_schedule/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Choose a day, a free time, and confirm.
class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final days = ref.watch(bookableDaysProvider);
    final booking = ref.watch(bookingProvider);
    final settings = ref.watch(settingsProvider).value ?? ClinicSettings.fallback;
    if (booking.booked != null) return _BookedView(appointment: booking.booked!, instructions: settings.instructions);
    if (days == null) return const Center(child: CircularProgressIndicator());
    final selected = booking.date ?? days.where((d) => d.free.isNotEmpty).firstOrNull?.date;
    final selectedDay = days.where((d) => d.date == selected).firstOrNull;
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        SectionCard(
          title: l.chooseDay,
          footer: l.clinicTimeNote(settings.timezone, settings.slotMinutes),
          child: _DayStrip(days: days, selected: selected),
        ),
        SectionCard(
          title: l.chooseTime,
          child: selectedDay == null
              ? Text(l.noAppointmentsAvailable)
              : _SlotGrid(day: selectedDay, selectedStart: booking.date == selectedDay.date ? booking.start : null),
        ),
        if (booking.start != null && selectedDay != null)
          _ConfirmCard(date: selectedDay.date, start: booking.start!, slotMinutes: settings.slotMinutes),
        if (booking.start == null) FormMessage(error: booking.error),
      ],
    );
  }
}

class _DayStrip extends ConsumerWidget {
  const _DayStrip({required this.days, required this.selected});

  final List<BookableDay> days;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final label = !d.open
              ? l.closed
              : d.free.isEmpty
              ? l.full
              : l.freeCount(d.free.length);
          return _DayChip(
            date: d.date,
            label: label,
            isToday: i == 0,
            selected: d.date == selected,
            onTap: d.free.isEmpty ? null : () => ref.read(bookingProvider.notifier).selectDate(d.date),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.label,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final String label;
  final bool isToday;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${longDate(context, date)}, $label',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isToday ? l.today : shortWeekday(context, date), style: Theme.of(context).textTheme.labelSmall),
                  Text('${dayOfMonth(date)}', style: Theme.of(context).textTheme.titleLarge),
                  Text(shortMonth(context, date), style: Theme.of(context).textTheme.labelSmall),
                  Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({required this.day, required this.selectedStart});

  final BookableDay day;
  final int? selectedStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    if (day.free.isEmpty) return Text(l.noTimesLeft);
    final groups = {for (final part in DayPart.values) part: day.free.where((s) => dayPartOf(s.start) == part).toList()}
      ..removeWhere((_, v) => v.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(longDate(context, day.date), style: Theme.of(context).textTheme.bodySmall),
        for (final MapEntry(key: part, value: slots) in groups.entries) ...[
          const SizedBox(height: 12),
          Text(switch (part) {
            DayPart.morning => l.morning,
            DayPart.afternoon => l.afternoon,
            DayPart.evening => l.evening,
          }, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in slots)
                ChoiceChip(
                  label: Text(timeLabel(context, s.start)),
                  selected: s.start == selectedStart,
                  onSelected: (_) => ref.read(bookingProvider.notifier).selectSlot(s.start),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConfirmCard extends ConsumerStatefulWidget {
  const _ConfirmCard({required this.date, required this.start, required this.slotMinutes});

  final String date;
  final int start;
  final int slotMinutes;

  @override
  ConsumerState<_ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends ConsumerState<_ConfirmCard> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final user = ref.watch(currentUserProvider).value;
    return SectionCard(
      title: l.confirm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(longDate(context, widget.date), style: Theme.of(context).textTheme.titleMedium),
          Text(timeRangeLabel(context, widget.start, widget.start + widget.slotMinutes)),
          if (user != null) Text(l.bookingAs(user.name, user.phone), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: l.reasonOptional),
          ),
          FormMessage(error: booking.error),
          const SizedBox(height: 12),
          BusyButton(
            label: l.confirmAppointment,
            busy: booking.busy,
            onPressed: () => ref.read(bookingProvider.notifier).confirm(_reason.text),
          ),
        ],
      ),
    );
  }
}

class _BookedView extends ConsumerWidget {
  const _BookedView({required this.appointment, required this.instructions});

  final Appointment appointment;
  final String instructions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        SectionCard(
          title: l.bookedTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.bookingReference, style: text.bodySmall),
              SelectableText(
                appointment.ref,
                style: text.headlineMedium?.copyWith(letterSpacing: 4, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${longDate(context, appointment.date)}, ${timeRangeLabel(context, appointment.start, appointment.end)}',
              ),
              if (instructions.isNotEmpty) ...[const SizedBox(height: 12), Text(instructions)],
              const SizedBox(height: 8),
              Text(l.bookedNote, style: text.bodySmall),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => ref.read(bookingProvider.notifier).reset(), child: Text(l.bookAnother)),
            ],
          ),
        ),
      ],
    );
  }
}
