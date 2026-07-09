import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The in-body screen header: title (optionally with the Ledgr logo mark) on
/// the left, `SoftIconButton`-style actions on the right. Screens use this
/// instead of a stock AppBar for a consistent, designed top edge.
class LedgrHeader extends StatelessWidget {
  const LedgrHeader({
    required this.title,
    this.showLogo = false,
    this.actions = const [],
    super.key,
  });

  final String title;
  final bool showLogo;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.lg, Gaps.md),
      child: Row(
        children: [
          if (showLogo) ...[
            const LedgrLogoMark(),
            const SizedBox(width: Gaps.md),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The brand mark: a small hero-gradient superellipse with a wallet glyph.
class LedgrLogoMark extends StatelessWidget {
  const LedgrLogoMark({this.size = 34, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size / 3),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: scheme.heroGradient,
        ),
      ),
      child: Icon(LucideIcons.wallet, size: size * 0.5, color: scheme.onHero),
    );
  }
}
