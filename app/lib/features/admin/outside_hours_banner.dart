import 'package:clinic_schedule/core/formatting.dart';
import 'package:clinic_schedule/features/admin/admin_providers.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Warns about booked appointments that are outside the current opening hours.
class OutsideHoursBanner extends ConsumerWidget {
  const OutsideHoursBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(outsideHoursProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.outsideHoursTitle(list.length),
              style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onTertiaryContainer),
            ),
            const SizedBox(height: 4),
            for (final a in list.take(10))
              Text(
                '• ${longDate(context, a.date)} ${timeLabel(context, a.start)} – ${a.patientName} (${a.phone}, ${a.ref})',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
          ],
        ),
      ),
    );
  }
}
