import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/notifications/notifications.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Frame around the tabs: app bar with the bell and log-out, bottom navigation on phones,
/// a navigation rail on tablets.
class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, required this.admin, super.key});

  final StatefulNavigationShell shell;
  final bool admin;

  static const _wideBreakpoint = 840.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value;
    final destinations = admin
        ? [
            (Icons.event_note_outlined, l.tabAppointments),
            (Icons.schedule_outlined, l.tabHours),
            (Icons.people_outline, l.tabUsers),
            (Icons.settings_outlined, l.tabSettings),
          ]
        : [(Icons.calendar_month_outlined, l.tabBook), (Icons.event_available_outlined, l.tabMyAppointments)];
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    void select(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings?.clinicName ?? l.appTitle),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: l.logOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(accountRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, label) in destinations)
                  NavigationRailDestination(icon: Icon(icon), label: Text(label)),
              ],
            ),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              destinations: [
                for (final (icon, label) in destinations) NavigationDestination(icon: Icon(icon), label: label),
              ],
            ),
    );
  }
}
