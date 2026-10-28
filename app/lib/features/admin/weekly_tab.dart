import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/admin/admin_hours_screen.dart';
import 'package:clinic_schedule/features/admin/hours_widgets.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/busy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The hours that repeat every week (1 = Monday … 7 = Sunday).
class WeeklyTab extends ConsumerStatefulWidget {
  const WeeklyTab({super.key});

  @override
  ConsumerState<WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends ConsumerState<WeeklyTab> {
  Map<int, List<TimeRange>>? _draft;
  bool _busy = false;

  Future<void> _save(Map<int, List<TimeRange>> week) async {
    setState(() => _busy = true);
    final ok = await runHoursChange(context, ref, () => ref.read(clinicRepositoryProvider).saveWeekly(week));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _draft = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saved = ref.watch(weeklyProvider).value;
    final mode = ref.watch(settingsProvider).value?.scheduleMode ?? ScheduleMode.weekly;
    if (saved == null) return const Center(child: CircularProgressIndicator());
    final week = _draft ?? saved;
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(
          mode == ScheduleMode.daily ? l.weeklyDailyModeNote : l.weeklyNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (var d = 1; d <= 7; d++)
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    longWeekday(context, addDays(referenceMonday, d - 1)),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  RangeEditor(ranges: week[d] ?? const [], onChanged: (r) => setState(() => _draft = {...week, d: r})),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        BusyButton(label: l.saveWeekly, busy: _busy, onPressed: _draft == null ? null : () => _save(week)),
      ],
    );
  }
}
