import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/admin/hours_widgets.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/confirm_dialog.dart';
import 'package:clinic_schedule/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dates from [from] to [to] (inclusive) whose weekday (1 = Monday … 7 = Sunday) is in [weekdays].
/// Pure, so it is unit-tested.
List<ClinicDate> datesMatching(ClinicDate from, ClinicDate to, Set<int> weekdays, {int max = 62}) {
  final out = <ClinicDate>[];
  for (var d = from; d.compareTo(to) <= 0 && out.length <= max; d = addDays(d, 1)) {
    if (weekdays.contains(weekdayOf(d))) out.add(d);
  }
  return out;
}

/// Open only selected slots on selected days (or close them / return them to the weekly timetable).
class PickSlotsTab extends ConsumerStatefulWidget {
  const PickSlotsTab({super.key});

  @override
  ConsumerState<PickSlotsTab> createState() => _PickSlotsTabState();
}

class _PickSlotsTabState extends ConsumerState<PickSlotsTab> {
  ClinicDate? _from;
  ClinicDate? _to;
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  Set<int> _selected = {};
  int _gridFrom = 8 * 60;
  int _gridTo = 22 * 60;

  Future<ClinicDate?> _pickDate(ClinicDate initial, ClinicDate today) async {
    final p = await showDatePicker(
      context: context,
      firstDate: calendarDay(today),
      lastDate: calendarDay(addDays(today, 365)),
      initialDate: calendarDay(initial),
    );
    return p == null ? null : dateKey(p.year, p.month, p.day);
  }

  Future<int?> _pickTime(int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _apply(List<ClinicDate> dates, String question, Future<Object?> Function() action) async {
    final l = AppLocalizations.of(context);
    if (dates.isEmpty) return showMessage(context, l.chooseAtLeastOneDay, error: true);
    if (dates.length > 62) return showMessage(context, l.atMost62Days, error: true);
    if (!await confirmAction(context, question)) return;
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = ref.watch(clinicNowProvider).value?.date;
    final slotMinutes = ref.watch(settingsProvider).value?.slotMinutes ?? ClinicSettings.fallback.slotMinutes;
    if (today == null) return const Center(child: CircularProgressIndicator());
    final from = _from ?? addDays(today, 1);
    final to = _to ?? addDays(today, 7);
    final dates = datesMatching(from, to, _weekdays);
    final grid = {...slotGrid(_gridFrom, _gridTo, slotMinutes), ..._selected}.toList()..sort();
    final repo = ref.read(clinicRepositoryProvider);
    final weekdayNames = [for (var d = 1; d <= 7; d++) shortWeekday(context, addDays(referenceMonday, d - 1))];
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(l.pickSlotsIntro, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SectionCard(
          title: l.days,
          footer: dates.isEmpty ? l.noDaysMatch : l.daysSelected(dates.length),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await _pickDate(from, today);
                      if (picked != null) setState(() => _from = picked);
                    },
                    child: Text(l.fromDate(longDate(context, from))),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await _pickDate(to, today);
                      if (picked != null) setState(() => _to = picked);
                    },
                    child: Text(l.toDate(longDate(context, to))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(weekdayNames[d - 1]),
                      selected: _weekdays.contains(d),
                      onSelected: (on) =>
                          setState(() => _weekdays = on ? {..._weekdays, d} : ({..._weekdays}..remove(d))),
                    ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: l.timesWithLength(slotMinutes),
          footer: l.slotsTicked(_selected.length),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.showTimes),
                  TextButton(
                    onPressed: () async {
                      final t = await _pickTime(_gridFrom);
                      if (t != null) setState(() => _gridFrom = t);
                    },
                    child: Text(timeLabel(context, _gridFrom)),
                  ),
                  Text(l.to),
                  TextButton(
                    onPressed: () async {
                      final t = await _pickTime(_gridTo);
                      if (t != null) setState(() => _gridTo = t == 0 ? 1440 : t);
                    },
                    child: Text(timeLabel(context, _gridTo)),
                  ),
                  TextButton(onPressed: () => setState(() => _selected = grid.toSet()), child: Text(l.selectAll)),
                  TextButton(onPressed: () => setState(() => _selected = {}), child: Text(l.clear)),
                ],
              ),
              SlotPicker(starts: grid, selected: _selected, onChanged: (s) => setState(() => _selected = s)),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => _apply(
                dates,
                _selected.isEmpty
                    ? l.noSlotsTickedQuestion(dates.length)
                    : l.openSlotsQuestion(_selected.length, dates.length),
                () => runHoursChange(context, ref, () => repo.setPickedSlots(dates, _selected.toList()..sort())),
              ),
              child: Text(l.openOnlyTheseSlots),
            ),
            OutlinedButton(
              onPressed: () => _apply(
                dates,
                l.closeDaysQuestion(dates.length),
                () => runHoursChange(context, ref, () => repo.setHours(dates, const [])),
              ),
              child: Text(l.closeTheseDays),
            ),
            OutlinedButton(
              onPressed: () => _apply(
                dates,
                l.resetDaysQuestion(dates.length),
                () => runHoursChange(context, ref, () => repo.clearDays(dates)),
              ),
              child: Text(l.backToWeekly),
            ),
          ],
        ),
      ],
    );
  }
}
