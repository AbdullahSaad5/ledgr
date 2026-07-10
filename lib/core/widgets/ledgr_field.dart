import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ledgr's labeled text input: a small bold label sits ABOVE a filled field.
/// Never uses Material's floating label, whose notch cuts through the
/// focused outline and reads as stock-Material.
class LedgrField extends StatelessWidget {
  const LedgrField({
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixText,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? prefixText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool obscureText;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: Text(
              label!,
              style: text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixText: prefixText,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18),
            counterText: '',
          ),
        ),
      ],
    );
  }
}
