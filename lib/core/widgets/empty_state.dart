import 'package:flutter/material.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';

/// A friendly empty-state placeholder: icon, title, and a one-line hint
/// (PLAN.md §7 — every empty screen gets one).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Center within the *visible* area: on tab screens the body extends
    // behind the floating nav bar, which MediaQuery reports as bottom padding.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, 32 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(
              icon: icon,
              color: theme.colorScheme.onSurfaceVariant,
              size: 76,
              iconSize: 34,
              background: theme.colorScheme.surfaceContainer,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
