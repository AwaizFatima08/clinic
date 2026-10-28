import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/admin/hours_widgets.dart';
import 'package:clinic_schedule/features/admin/pick_slots_tab.dart';
import 'package:clinic_schedule/features/admin/weekly_tab.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opening hours: day by day, picked slots on chosen days, and the weekly timetable.
class AdminHoursScreen extends StatelessWidget {
  const AdminHoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.dailyHours),
              Tab(text: l.pickSlots),
              Tab(text: l.weeklyTimetable),
            ],
          ),
          const Expanded(child: TabBarView(children: [_DailyTab(), PickSlotsTab(), WeeklyTab()])),
        ],
      ),
    );
  }
}

final StreamProvider<Map<int, List<TimeRange>>> weeklyProvider = StreamProvider.autoDispose<Map<int, List<TimeRange>>>(
  (ref) => ref.watch(clinicRepositoryProvider).watchWeekly(),
);

final NotifierProvider<_CalendarStart, ClinicDate?> _calendarStartProvider =
    NotifierProvider.autoDispose<_CalendarStart, ClinicDate?>(_CalendarStart.new);

class _CalendarStart extends Notifier<ClinicDate?> {
  @override
  ClinicDate? build() => ref.watch(clinicNowProvider.select((n) => n.value?.date));

  void shift(int days) {
    final s = state;
    if (s != null) state = addDays(s, days);
  }
}

final StreamProvider<Map<String, ClinicDay>> _calendarDaysProvider = StreamProvider.autoDispose<Map<String, ClinicDay>>(
  (ref) {
    final from = ref.watch(_calendarStartProvider);
    if (from == null) return const Stream.empty();
    return ref.watch(clinicRepositoryProvider).watchDays(from, addDays(from, 13));
  },
);

final StreamProvider<Map<String, DayOverride>> _calendarOverridesProvider =
    StreamProvider.autoDispose<Map<String, DayOverride>>((ref) {
      final from = ref.watch(_calendarStartProvider);
      if (from == null) return const Stream.empty();
      return ref.watch(clinicRepositoryProvider).watchOverrides(from, addDays(from, 13));
    });

class _DailyTab extends ConsumerWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final from = ref.watch(_calendarStartProvider);
    final days = ref.watch(_calendarDaysProvider).value ?? const {};
    final overrides = ref.watch(_calendarOverridesProvider).value ?? const {};
    final weekly = ref.watch(weeklyProvider).value ?? const {};
    final mode = ref.watch(settingsProvider).value?.scheduleMode ?? ScheduleMode.weekly;
    if (from == null) return const Center(child: CircularProgressIndicator());
    final notifier = ref.read(_calendarStartProvider.notifier);
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(
          mode == ScheduleMode.daily ? l.modeDailyNote : l.modeWeeklyNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => notifier.shift(-14),
              icon: const Icon(Icons.chevron_left),
              label: Text(l.twoWeeks),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => notifier.shift(14),
              icon: const Icon(Icons.chevron_right),
              label: Text(l.twoWeeks),
            ),
          ],
        ),
        for (var i = 0; i < 14; i++)
          () {
            final date = addDays(from, i);
            return _DayCard(
              date: date,
              day: days[date],
              dayOverride: overrides[date],
              weeklyHours: weekly[weekdayOf(date)] ?? const [],
              mode: mode,
            );
          }(),
      ],
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.date,
    required this.day,
    required this.dayOverride,
    required this.weeklyHours,
    required this.mode,
  });

  final ClinicDate date;
  final ClinicDay? day;
  final DayOverride? dayOverride;
  final List<TimeRange> weeklyHours;
  final ScheduleMode mode;

  List<TimeRange> get _currentHours => switch (day?.source) {
    DaySource.hours => dayOverride?.intervals ?? const [],
    DaySource.weekly => weeklyHours,
    _ => const [],
  };

  List<TimeRange> get _prefill =>
      _currentHours.isNotEmpty ? _currentHours : (weeklyHours.isNotEmpty ? weeklyHours : const [TimeRange(540, 1020)]);

  Future<void> _editHours(BuildContext context, WidgetRef ref) async {
    final ranges = await showDialog<List<TimeRange>>(
      context: context,
      builder: (_) => _HoursDialog(date: date, initial: _prefill),
    );
    if (ranges == null || !context.mounted) return;
    await runHoursChange(context, ref, () => ref.read(clinicRepositoryProvider).setHours([date], ranges));
  }

  Future<void> _pickSlots(BuildContext context, WidgetRef ref, int slotMinutes) async {
    final current = dayOverride?.isSlots ?? false
        ? dayOverride!.starts.toSet()
        : {for (final s in day?.slots ?? const <TimeRange>[]) s.start};
    final taken = {for (final t in day?.taken ?? const <TimeRange>[]) t.start};
    final starts = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _PickDialog(date: date, initial: current, taken: taken, slotMinutes: slotMinutes),
    );
    if (starts == null || !context.mounted) return;
    await runHoursChange(
      context,
      ref,
      () => ref.read(clinicRepositoryProvider).setPickedSlots([date], starts.toList()..sort()),
    );
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final booked = day?.taken.length ?? 0;
    if (!await confirmAction(context, booked > 0 ? l.closeDayWithBookings(booked) : l.closeDayQuestion)) return;
    if (!context.mounted) return;
    await runHoursChange(context, ref, () => ref.read(clinicRepositoryProvider).setHours([date], const []));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? ClinicSettings.fallback;
    final now = ref.watch(clinicNowProvider).value;
    final open = day?.open ?? false;
    final free = day == null || now == null
        ? 0
        : bookableSlots(
            date: date,
            slots: day!.slots,
            taken: day!.taken,
            now: now,
            minNoticeMinutes: 0,
            bookingWindowDays: 9999,
            forAdmin: true,
          ).length;
    final source = day?.source ?? (mode == ScheduleMode.daily ? DaySource.notActivated : DaySource.weekly);
    final hoursText = source == DaySource.slots
        ? (day?.slots.map((s) => timeLabel(context, s.start)).join(', ') ?? '')
        : _currentHours.isEmpty
        ? l.closed
        : _currentHours.map((r) => timeRangeLabel(context, r.start, r.end)).join(', ');
    final repo = ref.read(clinicRepositoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(longDate(context, date), style: Theme.of(context).textTheme.titleSmall),
            Text(switch (source) {
              DaySource.weekly => l.sourceWeekly,
              DaySource.hours => l.sourceHours,
              DaySource.slots => l.sourceSlots,
              DaySource.notActivated => l.sourceNotOpened,
            }, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 4),
            Text(hoursText.isEmpty ? l.closed : hoursText),
            Text(l.bookedAndFree(day?.taken.length ?? 0, free), style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 4,
              children: [
                if (!open)
                  TextButton(
                    onPressed: () => runHoursChange(context, ref, () => repo.setHours([date], _prefill)),
                    child: Text(l.open),
                  ),
                TextButton(
                  onPressed: () => _editHours(context, ref),
                  child: Text(open ? l.editHours : l.openCustomHours),
                ),
                TextButton(onPressed: () => _pickSlots(context, ref, settings.slotMinutes), child: Text(l.pickSlots)),
                if (open) TextButton(onPressed: () => _close(context, ref), child: Text(l.closeDay)),
                if (dayOverride != null)
                  TextButton(
                    onPressed: () => runHoursChange(context, ref, () => repo.clearDays([date])),
                    child: Text(mode == ScheduleMode.weekly ? l.useWeekly : l.removeOpening),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoursDialog extends StatefulWidget {
  const _HoursDialog({required this.date, required this.initial});

  final ClinicDate date;
  final List<TimeRange> initial;

  @override
  State<_HoursDialog> createState() => _HoursDialogState();
}

class _HoursDialogState extends State<_HoursDialog> {
  late List<TimeRange> _ranges = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(longDate(context, widget.date)),
      content: SingleChildScrollView(
        child: RangeEditor(ranges: _ranges, onChanged: (r) => setState(() => _ranges = r)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_ranges), child: Text(l.save)),
      ],
    );
  }
}

class _PickDialog extends StatefulWidget {
  const _PickDialog({required this.date, required this.initial, required this.taken, required this.slotMinutes});

  final ClinicDate date;
  final Set<int> initial;
  final Set<int> taken;
  final int slotMinutes;

  @override
  State<_PickDialog> createState() => _PickDialogState();
}

class _PickDialogState extends State<_PickDialog> {
  late Set<int> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final grid = {...slotGrid(8 * 60, 22 * 60, widget.slotMinutes), ..._selected}.toList()..sort();
    return AlertDialog(
      title: Text(longDate(context, widget.date)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.pickSlotsHelp),
            const SizedBox(height: 8),
            SlotPicker(
              starts: grid,
              selected: _selected,
              taken: widget.taken,
              onChanged: (s) => setState(() => _selected = s),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_selected), child: Text(l.save)),
      ],
    );
  }
}
