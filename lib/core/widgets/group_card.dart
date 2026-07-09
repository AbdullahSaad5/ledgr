import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';

/// A labelled group of rows in one card with hairline dividers — the standard
/// way to present grouped list content (settings sections, account groups).
class GroupCard extends StatelessWidget {
  const GroupCard({required this.children, this.title, super.key});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, Gaps.xl, 4, Gaps.sm),
            child: Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0)
                  Divider(indent: Gaps.lg, color: scheme.outlineVariant),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
