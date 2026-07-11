import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One destination in [LedgrNavBar].
class LedgrNavItem {
  const LedgrNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The app's floating pill navigation bar with the log-transaction FAB set
/// into its center. Labels stay visible for accessibility; the active
/// destination gets an animated tonal pill behind its icon.
class LedgrNavBar extends StatelessWidget {
  const LedgrNavBar({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onFab,
    super.key,
  });

  final List<LedgrNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onFab;

  /// Bottom clearance a tab screen's scroll view needs so its last item can
  /// scroll clear of the floating bar. The shell uses extendBody, so the
  /// Scaffold already reports the bar's full height (system inset included)
  /// as the body's bottom MediaQuery padding — but an explicit `padding:` on
  /// a scroll view discards that ambient inset, so screens must add it back
  /// via this helper instead of a fixed spacer (which is short by the system
  /// inset on 3-button navigation).
  static double clearanceOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + Gaps.lg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final half = items.length ~/ 2;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: ShapeDecoration(
          color: isDark ? scheme.surfaceContainerLow : Colors.white,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(32),
            side: isDark
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final (i, item) in items.indexed) ...[
              if (i == half) _NavFab(onPressed: onFab),
              Expanded(
                child: _NavDestination(
                  item: item,
                  selected: i == currentIndex,
                  onTap: () => onSelect(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LedgrNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      customBorder: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(item.icon, size: 21, color: color),
            ),
            const SizedBox(height: 4),
            // Nav labels don't follow the system font scale (standard for
            // bottom bars) so every label stays one line at the same size.
            Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textScaler: TextScaler.noScaling,
              style: text.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gradient log-transaction button set into the bar. Remains a real
/// [FloatingActionButton] for semantics and tests; the gradient shell paints
/// underneath it.
class _NavFab extends StatelessWidget {
  const _NavFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scheme.heroGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.heroGradient.last.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'add-transaction',
          tooltip: 'Log a transaction',
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onHero,
          shape: const CircleBorder(),
          onPressed: onPressed,
          child: const Icon(LucideIcons.plus, size: 26),
        ),
      ),
    );
  }
}
