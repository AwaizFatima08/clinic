import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// Asks a yes/no question; returns true only when confirmed.
Future<bool> confirmAction(BuildContext context, String question, {String? confirmLabel}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.no)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel ?? l.yes)),
      ],
    ),
  );
  return ok ?? false;
}

/// Shows a short message at the bottom of the screen.
void showMessage(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? scheme.error : null),
  );
}
