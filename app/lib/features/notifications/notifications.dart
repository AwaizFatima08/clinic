import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live notifications for the signed-in person (admin feed for admins).
final StreamProvider<List<AppNotification>> notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((
  ref,
) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watch(admin: user.isAdmin, uid: user.uid);
});

/// Derived, not stored: how many are unread.
final Provider<int> unreadCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0,
);

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: unread == 0 ? l.notifications : l.notificationsUnread(unread),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _NotificationSheet(),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(notificationsProvider).value ?? const <AppNotification>[];
    final unreadIds = [
      for (final n in items)
        if (!n.read) n.id,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => Column(
        children: [
          ListTile(
            title: Text(l.notifications, style: Theme.of(context).textTheme.titleMedium),
            trailing: unreadIds.isEmpty
                ? null
                : TextButton(
                    onPressed: () => ref.read(notificationRepositoryProvider).markRead(unreadIds),
                    child: Text(l.markAllRead),
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(l.noNotifications))
                : ListView.separated(
                    controller: controller,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _NotificationTile(item: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: item.read ? null : scheme.secondaryContainer.withValues(alpha: 0.5),
      leading: Icon(item.read ? Icons.notifications_none : Icons.notifications_active, color: scheme.primary),
      title: Text(item.title, style: TextStyle(fontWeight: item.read ? FontWeight.normal : FontWeight.w600)),
      subtitle: Text('${item.body}\n${shortDateTime(context, item.createdAt)}'),
      isThreeLine: true,
      onTap: item.read ? null : () => ref.read(notificationRepositoryProvider).markRead([item.id]),
    );
  }
}
