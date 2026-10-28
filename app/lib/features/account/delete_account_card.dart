import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Delete my account" (Google Play's in-app account deletion). The server cancels
/// upcoming appointments, anonymises past ones and deletes the login; the router then
/// returns to the login screen.
class DeleteAccountCard extends ConsumerStatefulWidget {
  const DeleteAccountCard({this.admin = false, super.key});

  /// Admins see a note that the last admin cannot leave.
  final bool admin;

  @override
  ConsumerState<DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends ConsumerState<DeleteAccountCard> {
  bool _busy = false;

  Future<void> _delete() async {
    if (!await _confirm(context) || !mounted) return;
    setState(() => _busy = true);
    // Read before the call: once signed out, this screen may be gone.
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = await ref.read(accountRepositoryProvider).deleteMyAccount();
    if (mounted) setState(() => _busy = false);
    final (text, error) = switch (result) {
      Ok() => (l.accountDeleted, false),
      Err(:final failure) => (failure.message, true),
    };
    messenger.showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? scheme.error : null));
  }

  Future<bool> _confirm(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAccountQuestion),
        content: SingleChildScrollView(child: Text(l.deleteAccountDetails)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.keepAccount)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.deleteAccountConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: l.deleteAccountTitle,
      footer: widget.admin ? l.deleteAccountAdminNote : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.deleteAccountIntro),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _busy ? null : _delete,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_forever_outlined),
            label: Text(l.deleteAccountButton),
          ),
        ],
      ),
    );
  }
}
