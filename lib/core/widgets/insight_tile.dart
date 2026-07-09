import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';

/// A small labelled insight: caption, bold value, optional context line.
/// Used in pairs/grids on the reports screens.
class InsightTile extends StatelessWidget {
  const InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.accent,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Gaps.lg),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
          side: scheme.brightness == Brightness.dark
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent ?? scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(
                color: accent ?? scheme.onSurface,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
