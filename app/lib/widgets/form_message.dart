import 'package:flutter/material.dart';

/// An error or confirmation line under a form, announced to screen readers.
class FormMessage extends StatelessWidget {
  const FormMessage({this.error, this.info, super.key});

  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final text = error ?? info;
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isError = error != null;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsetsDirectional.only(top: 12),
        padding: const EdgeInsetsDirectional.all(12),
        decoration: BoxDecoration(
          color: isError ? scheme.errorContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? scheme.onErrorContainer : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: isError ? scheme.onErrorContainer : scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
