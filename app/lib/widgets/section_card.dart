import 'package:flutter/material.dart';

/// A titled card used for each step / section of a screen.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.child, this.footer, this.trailing, super.key});

  final String title;
  final Widget child;
  final String? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text(title, style: text.titleMedium)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
            if (footer != null) ...[const SizedBox(height: 8), Text(footer!, style: text.bodySmall)],
          ],
        ),
      ),
    );
  }
}
