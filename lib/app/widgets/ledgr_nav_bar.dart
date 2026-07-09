import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';

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

    return InkWell(
      onTap: onTap,
      customBorder: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 28,
              decoration: ShapeDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: text.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 56,
        height: 56,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scheme.heroGradient,
          ),
          shadows: [
            BoxShadow(
              color: scheme.heroGradient.last.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
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
          onPressed: onPressed,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}
