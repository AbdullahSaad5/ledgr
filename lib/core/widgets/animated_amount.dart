import 'package:flutter/material.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/widgets/amount_text.dart';

/// An [AmountText] that count-up animates when its value changes.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount(
    this.money, {
    required this.formatter,
    this.tone = AmountTone.neutral,
    this.style,
    super.key,
  });

  final Money money;
  final MoneyFormatter formatter;
  final AmountTone tone;
  final TextStyle? style;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> {
  late int _from = widget.money.minor;

  @override
  void didUpdateWidget(AnimatedAmount old) {
    super.didUpdateWidget(old);
    if (old.money.minor != widget.money.minor) _from = old.money.minor;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from.toDouble(), end: widget.money.minor.toDouble()),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => AmountText(
        Money(minor: value.round(), currency: widget.money.currency),
        formatter: widget.formatter,
        tone: widget.tone,
        style: widget.style,
      ),
    );
  }
}
