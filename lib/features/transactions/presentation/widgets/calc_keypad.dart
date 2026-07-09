import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ledgr/core/money/keypad_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The calculator keypad (PLAN.md §6.3). Drives a [KeypadController]; calls
/// [onChanged] after each key so the parent can rebuild the amount display.
/// Keys are superellipse tiles with a press-scale response and haptics.
class CalcKeypad extends StatelessWidget {
  const CalcKeypad({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final KeypadController controller;
  final VoidCallback onChanged;

  void _tap(void Function() action) {
    HapticFeedback.selectionClick();
    action();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, [
          _Key.digit('7'),
          _Key.digit('8'),
          _Key.digit('9'),
          _Key.op('÷', '/'),
        ]),
        _row(context, [
          _Key.digit('4'),
          _Key.digit('5'),
          _Key.digit('6'),
          _Key.op('×', '*'),
        ]),
        _row(context, [
          _Key.digit('1'),
          _Key.digit('2'),
          _Key.digit('3'),
          _Key.op('−', '-'),
        ]),
        _row(context, [
          _Key.digit('.'),
          _Key.digit('0'),
          _Key.backspace(),
          _Key.op('+', '+'),
        ]),
      ],
    );
  }

  Widget _row(BuildContext context, List<_Key> keys) {
    return Expanded(
      child: Row(
        children: [
          for (final key in keys)
            Expanded(
              child: _KeypadButton(
                keyDef: key,
                onTap: () => _tap(() => _apply(key)),
              ),
            ),
        ],
      ),
    );
  }

  void _apply(_Key key) {
    switch (key.kind) {
      case _KeyKind.digit:
        if (key.value == '.') {
          controller.pressDecimal();
        } else {
          controller.pressDigit(key.value);
        }
      case _KeyKind.operator:
        controller.pressOperator(key.value);
      case _KeyKind.backspace:
        controller.backspace();
    }
  }
}

class _KeypadButton extends StatefulWidget {
  const _KeypadButton({required this.keyDef, required this.onTap});

  final _Key keyDef;
  final VoidCallback onTap;

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = widget.keyDef;
    final isOp = key.kind == _KeyKind.operator;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Material(
            color: isOp ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: widget.onTap,
              child: Center(
                child: key.kind == _KeyKind.backspace
                    ? Icon(LucideIcons.delete, color: scheme.onSurfaceVariant)
                    : Text(
                        key.label,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: isOp
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                            ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _KeyKind { digit, operator, backspace }

class _Key {
  const _Key(this.label, this.value, this.kind);
  _Key.digit(String d) : this(d, d, _KeyKind.digit);
  _Key.op(String label, String value) : this(label, value, _KeyKind.operator);
  _Key.backspace() : this('⌫', 'back', _KeyKind.backspace);

  final String label;
  final String value;
  final _KeyKind kind;
}
