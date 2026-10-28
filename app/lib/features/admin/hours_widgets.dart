import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/features/admin/admin_providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs an hours change and reports the result (and any appointments now outside the hours).
Future<bool> runHoursChange(
  BuildContext context,
  WidgetRef ref,
  Future<Result<List<Appointment>>> Function() change,
) async {
  final l = AppLocalizations.of(context);
  final result = await change();
  if (!context.mounted) return false;
  ref.invalidate(outsideHoursProvider);
  switch (result) {
    case Ok(:final value):
      showMessage(context, value.isEmpty ? l.saved : l.savedWithOutside(value.length));
      return true;
    case Err(:final failure):
      showMessage(context, failure.message, error: true);
      return false;
  }
}

/// Edits a list of opening ranges (e.g. 10:00–13:00, 17:00–20:00). No ranges = closed.
class RangeEditor extends StatelessWidget {
  const RangeEditor({required this.ranges, required this.onChanged, super.key});

  final List<TimeRange> ranges;
  final ValueChanged<List<TimeRange>> onChanged;

  Future<int?> _pick(BuildContext context, int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _edit(BuildContext context, int index, {required bool start}) async {
    final r = ranges[index];
    final picked = await _pick(context, start ? r.start : r.end);
    if (picked == null) return;
    // 00:00 as an end time means midnight at the end of the day.
    final next = start ? TimeRange(picked, r.end) : TimeRange(r.start, picked == 0 ? 1440 : picked);
    onChanged([...ranges]..[index] = next);
  }

  TimeRange _suggestNext() {
    if (ranges.isEmpty) return const TimeRange(9 * 60, 17 * 60);
    final lastEnd = ranges.map((r) => r.end).reduce((a, b) => a > b ? a : b);
    final start = (lastEnd + 60).clamp(0, 22 * 60);
    return TimeRange(start, (start + 180).clamp(start + 30, 1440));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ranges.isEmpty) Text(l.closed, style: Theme.of(context).textTheme.bodySmall),
        for (var i = 0; i < ranges.length; i++)
          Row(
            children: [
              TextButton(
                onPressed: () => _edit(context, i, start: true),
                child: Text(timeLabel(context, ranges[i].start)),
              ),
              Text(l.to),
              TextButton(
                onPressed: () => _edit(context, i, start: false),
                child: Text(timeLabel(context, ranges[i].end)),
              ),
              IconButton(
                tooltip: l.remove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onChanged([...ranges]..removeAt(i)),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: () => onChanged([...ranges, _suggestNext()]),
          icon: const Icon(Icons.add),
          label: Text(l.addRange),
        ),
      ],
    );
  }
}

/// A grid of slot start times to tick on/off.
class SlotPicker extends StatelessWidget {
  const SlotPicker({
    required this.starts,
    required this.selected,
    required this.onChanged,
    this.taken = const {},
    super.key,
  });

  final List<int> starts;
  final Set<int> selected;
  final Set<int> taken;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in starts)
          FilterChip(
            label: Text(timeLabel(context, s)),
            tooltip: taken.contains(s) ? l.alreadyBooked : null,
            avatar: taken.contains(s) ? const Icon(Icons.person, size: 16) : null,
            selected: selected.contains(s),
            onSelected: (on) => onChanged(on ? ({...selected, s}) : ({...selected}..remove(s))),
          ),
      ],
    );
  }
}
