import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      AppointmentStatus.booked => (l.statusBooked, scheme.primaryContainer, scheme.onPrimaryContainer),
      AppointmentStatus.completed => (l.statusCompleted, scheme.secondaryContainer, scheme.onSecondaryContainer),
      AppointmentStatus.noShow => (l.statusMissed, scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AppointmentStatus.cancelled => (l.statusCancelled, scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
