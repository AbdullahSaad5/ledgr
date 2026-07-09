import 'package:flutter/material.dart';

/// The app's standard header action: a quiet, borderless icon button with a
/// tight footprint (no boxed background — headers stay calm).
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22, color: scheme.onSurface),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    );
  }
}
