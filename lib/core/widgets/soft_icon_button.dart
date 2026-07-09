import 'package:flutter/material.dart';

/// The app's standard header action: a soft tonal superellipse icon button.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(size / 3),
    );
    final button = Material(
      color: scheme.surfaceContainer,
      shape: shape,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.45, color: scheme.onSurface),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
