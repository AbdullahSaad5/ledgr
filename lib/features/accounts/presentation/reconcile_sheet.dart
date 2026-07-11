import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:ledgr/core/widgets/sheet_insets.dart';

/// Reconcile an account: enter the real balance; the app posts an adjustment
/// for the difference (ADR-0003).
class ReconcileSheet extends ConsumerStatefulWidget {
  const ReconcileSheet({
    required this.account,
    required this.currentMinor,
    super.key,
  });

  final Account account;
  final int currentMinor;

  static Future<void> show(
    BuildContext context, {
    required Account account,
    required int currentMinor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          ReconcileSheet(account: account, currentMinor: currentMinor),
    );
  }

  @override
  ConsumerState<ReconcileSheet> createState() => _ReconcileSheetState();
}

class _ReconcileSheetState extends ConsumerState<ReconcileSheet> {
  late final TextEditingController _actual = TextEditingController(
    text: Money(
      minor: widget.currentMinor,
      currency: widget.account.currency,
    ).toDecimal().toString(),
  );

  @override
  void dispose() {
    _actual.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final target = MoneyField.parse(_actual.text, widget.account.currency);
    await ref
        .read(accountRepositoryProvider)
        .reconcile(widget.account.id, targetMinor: target.minor);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        sheetBottomInset(context, min: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reconcile ${widget.account.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tracked balance'),
              AmountText(
                Money(
                  minor: widget.currentMinor,
                  currency: widget.account.currency,
                ),
                formatter: formatter,
                tone: AmountTone.auto,
              ),
            ],
          ),
          const SizedBox(height: 16),
          MoneyField(
            controller: _actual,
            currency: widget.account.currency,
            label: 'Actual balance now',
            symbol: settings.currencySymbol,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _apply,
            child: const Text('Create adjustment'),
          ),
        ],
      ),
    );
  }
}
