import 'dart:async';

import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/confirm_dialog.dart';
import 'package:clinic_schedule/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

final StreamProvider<List<AppUser>> allUsersProvider = StreamProvider.autoDispose<List<AppUser>>(
  (ref) => ref.watch(userRepositoryProvider).watchAll(),
);

/// Search text and role filter on the Users tab.
final class UserFilter {
  const UserFilter({this.query = '', this.role});

  final String query;
  final UserRole? role;
}

class UserFilterNotifier extends Notifier<UserFilter> {
  @override
  UserFilter build() => const UserFilter();

  void setQuery(String q) => state = UserFilter(query: q, role: state.role);
  void setRole(UserRole? r) => state = UserFilter(query: state.query, role: r);
}

final NotifierProvider<UserFilterNotifier, UserFilter> userFilterProvider =
    NotifierProvider.autoDispose<UserFilterNotifier, UserFilter>(UserFilterNotifier.new);

/// Derived: users matching the filter.
final Provider<AsyncValue<List<AppUser>>> filteredUsersProvider = Provider.autoDispose<AsyncValue<List<AppUser>>>((
  ref,
) {
  final f = ref.watch(userFilterProvider);
  final q = f.query.trim().toLowerCase();
  return ref
      .watch(allUsersProvider)
      .whenData(
        (all) => all
            .where(
              (u) =>
                  (f.role == null || u.role == f.role) &&
                  (q.isEmpty || '${u.name} ${u.phone} ${u.email}'.toLowerCase().contains(q)),
            )
            .toList(),
      );
});

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final users = ref.watch(filteredUsersProvider);
    final me = ref.watch(authUserProvider).value?.uid;
    final filter = ref.watch(userFilterProvider);
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(l.usersIntro, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(labelText: l.searchUsers, prefixIcon: const Icon(Icons.search)),
          onChanged: ref.read(userFilterProvider.notifier).setQuery,
        ),
        const SizedBox(height: 8),
        SegmentedButton<UserRole?>(
          segments: [
            ButtonSegment(value: null, label: Text(l.all)),
            ButtonSegment(value: UserRole.patient, label: Text(l.patients)),
            ButtonSegment(value: UserRole.admin, label: Text(l.admins)),
          ],
          selected: {filter.role},
          onSelectionChanged: (s) => ref.read(userFilterProvider.notifier).setRole(s.first),
        ),
        const SizedBox(height: 8),
        ...users.when(
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (_, _) => [Text(l.loadError)],
          data: (list) =>
              list.isEmpty ? [Text(l.noUsers)] : [for (final u in list) _UserCard(user: u, isMe: u.uid == me)],
        ),
      ],
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user, required this.isMe});

  final AppUser user;
  final bool isMe;

  Future<void> _changeRole(BuildContext context, WidgetRef ref, UserRole role) async {
    final l = AppLocalizations.of(context);
    final who = user.name.isEmpty ? user.email : user.name;
    final question = role == UserRole.admin ? l.makeAdminQuestion(who) : l.removeAdminQuestion(who);
    if (!await confirmAction(context, question)) return;
    final result = await ref.read(userRepositoryProvider).setRole(user.uid, role);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showMessage(context, role == UserRole.admin ? l.nowAdmin(who) : l.nowPatient(who));
      case Err(:final failure):
        showMessage(context, failure.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(user.name.isEmpty ? user.email : user.name),
        subtitle: Text(
          [
            user.phone,
            user.email,
            if (user.lastLoginAt != null) l.lastLogin(shortDateTime(context, user.lastLoginAt)),
          ].where((s) => s.isNotEmpty).join('\n'),
        ),
        isThreeLine: true,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _UserAppointments(user: user, canDelete: !isMe),
        ),
        trailing: isMe
            ? Chip(label: Text(l.adminYou))
            : DropdownButton<UserRole>(
                value: user.role,
                onChanged: (r) {
                  if (r != null && r != user.role) unawaited(_changeRole(context, ref, r));
                },
                items: [
                  DropdownMenuItem(value: UserRole.patient, child: Text(l.rolePatient)),
                  DropdownMenuItem(value: UserRole.admin, child: Text(l.roleAdmin)),
                ],
              ),
      ),
    );
  }
}

final FutureProviderFamily<List<Appointment>, String> _userAppointmentsProvider = FutureProvider.autoDispose
    .family<List<Appointment>, String>(
      (ref, uid) => ref.watch(appointmentRepositoryProvider).forPatient(uid),
    );

class _UserAppointments extends ConsumerWidget {
  const _UserAppointments({required this.user, required this.canDelete});

  final AppUser user;
  final bool canDelete;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final who = user.name.isEmpty ? user.email : user.name;
    if (!await confirmAction(context, l.deleteUserQuestion(who), confirmLabel: l.deleteAccountConfirm)) return;
    final result = await ref.read(userRepositoryProvider).deleteUser(user.uid);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showMessage(context, l.userDeleted(who));
        Navigator.of(context).pop();
      case Err(:final failure):
        showMessage(context, failure.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(_userAppointmentsProvider(user.uid));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(user.name.isEmpty ? user.email : user.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${user.phone} · ${user.email}'),
          const Divider(),
          ...list.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (_, _) => [Text(l.loadError)],
            data: (items) => items.isEmpty
                ? [Text(l.nothingYet)]
                : [
                    for (final a in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${longDate(context, a.date)} · ${timeLabel(context, a.start)}'),
                        subtitle: a.reason.isEmpty ? null : Text(a.reason),
                        trailing: StatusBadge(status: a.status),
                      ),
                  ],
          ),
          if (canDelete) ...[
            const Divider(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l.deleteUserButton),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
