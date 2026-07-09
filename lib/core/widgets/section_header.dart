import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';

/// A screen-section title with an optional trailing action ("See all").
/// Every list section in the app uses this for consistent rhythm.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel = 'See all',
    this.onAction,
    super.key,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xl, Gaps.md, Gaps.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
