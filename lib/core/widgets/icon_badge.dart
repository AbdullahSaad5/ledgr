import 'package:flutter/material.dart';

/// The app's standard icon container: a tinted superellipse holding an icon.
/// Used by transaction rows, account cards, hero stats, and pickers so every
/// icon in the app sits in the same shape language.
class IconBadge extends StatelessWidget {
  const IconBadge({
    required this.icon,
    required this.color,
    this.size = 42,
    this.iconSize,
    this.background,
    super.key,
  });

  /// Solid-fill variant (e.g. selected state) — icon drawn in [onColor].
  const IconBadge.filled({
    required this.icon,
    required Color fill,
    required Color onColor,
    this.size = 42,
    this.iconSize,
    super.key,
  }) : color = onColor,
       background = fill;

  final IconData icon;

  /// Icon color; also drives the default translucent background tint.
  final Color color;
  final double size;
  final double? iconSize;

  /// Overrides the derived translucent tint.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size / 3),
        ),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.48, color: color),
    );
  }
}
