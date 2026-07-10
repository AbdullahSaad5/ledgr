import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One choice offered by a [LedgrSelect].
class LedgrSelectOption<T> {
  const LedgrSelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

/// Ledgr's replacement for Material dropdowns: a filled superellipse field
/// that opens a bottom-sheet option list (matching the app's sheet language)
/// instead of a floating menu.
class LedgrSelect<T> extends StatelessWidget {
  const LedgrSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  /// Field label; also the sheet title.
  final String label;

  final T value;
  final List<LedgrSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Compact renders as a small pill (for ListTile trailers); the default
  /// renders as a full-width field.
  final bool compact;

  LedgrSelectOption<T>? get _selected {
    final matches = options.where((o) => o.value == value);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _open(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final picked = await showModalBottomSheet<(T,)>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Gaps.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, Gaps.sm),
              child: Text(label, style: text.titleMedium),
            ),
            for (final o in options)
              ListTile(
                leading: o.icon == null
                    ? null
                    : Icon(
                        o.icon,
                        size: 20,
                        color: o.iconColor ?? scheme.onSurfaceVariant,
                      ),
                title: Text(
                  o.label,
                  style: o.value == value
                      ? text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        )
                      : text.bodyLarge,
                ),
                trailing: o.value == value
                    ? Icon(LucideIcons.check, size: 18, color: scheme.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop((o.value,)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = _selected;

    if (compact) {
      return InkWell(
        customBorder: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected?.label ?? '—',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronsUpDown,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      customBorder: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onTap: () => _open(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 12),
        decoration: ShapeDecoration(
          color: scheme.surfaceContainer,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            if (selected?.icon != null) ...[
              Icon(
                selected!.icon,
                size: 20,
                color: selected.iconColor ?? scheme.primary,
              ),
              const SizedBox(width: Gaps.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected?.label ?? 'Choose…',
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronsUpDown,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
