import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';

/// Full filter editor for the search screen.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late TransactionFilter _draft = ref.read(transactionFilterProvider);
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currency = ref.read(appSettingsProvider).homeCurrency;
    if (_draft.minMinor != null) {
      _min.text = (_draft.minMinor! / _pow(currency)).toString();
    }
    if (_draft.maxMinor != null) {
      _max.text = (_draft.maxMinor! / _pow(currency)).toString();
    }
  }

  int _pow(String currency) {
    final digits = MoneyField.parse('1', currency).decimalDigits;
    var p = 1;
    for (var i = 0; i < digits; i++) {
      p *= 10;
    }
    return p;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final currency = ref.read(appSettingsProvider).homeCurrency;
    final min = _min.text.trim().isEmpty
        ? null
        : MoneyField.parse(_min.text, currency).minor;
    final max = _max.text.trim().isEmpty
        ? null
        : MoneyField.parse(_max.text, currency).minor;
    ref.read(transactionFilterProvider.notifier).state = _draft.copyWith(
      minMinor: min,
      maxMinor: max,
      clearAmounts: min == null && max == null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final expense =
        ref.watch(categoriesByKindProvider(CategoryKind.expense)).valueOrNull ??
        const [];
    final income =
        ref.watch(categoriesByKindProvider(CategoryKind.income)).valueOrNull ??
        const [];
    final tags = ref.watch(allTagsProvider).valueOrNull ?? const [];
    final settings = ref.watch(appSettingsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () {
                    ref.read(transactionFilterProvider.notifier).state =
                        const TransactionFilter();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _section('Type'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in TxType.values)
                  FilterChip(
                    label: Text(_typeLabel(t)),
                    selected: _draft.types.contains(t),
                    onSelected: (v) => setState(() {
                      _draft = _draft.copyWith(
                        types: {..._draft.types}..toggle(t, v),
                      );
                    }),
                  ),
              ],
            ),
            _section('Accounts'),
            Wrap(
              spacing: 8,
              children: [
                for (final a in accounts)
                  FilterChip(
                    label: Text(a.name),
                    selected: _draft.accountIds.contains(a.id),
                    onSelected: (v) => setState(() {
                      _draft = _draft.copyWith(
                        accountIds: {..._draft.accountIds}..toggle(a.id, v),
                      );
                    }),
                  ),
              ],
            ),
            _section('Categories'),
            Wrap(
              spacing: 8,
              children: [
                for (final c in [...expense, ...income])
                  FilterChip(
                    label: Text(c.name),
                    selected: _draft.categoryIds.contains(c.id),
                    onSelected: (v) => setState(() {
                      _draft = _draft.copyWith(
                        categoryIds: {..._draft.categoryIds}..toggle(c.id, v),
                      );
                    }),
                  ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              _section('Tags'),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in tags)
                    FilterChip(
                      label: Text(t.name),
                      selected: _draft.tagIds.contains(t.id),
                      onSelected: (v) => setState(() {
                        _draft = _draft.copyWith(
                          tagIds: {..._draft.tagIds}..toggle(t.id, v),
                        );
                      }),
                    ),
                ],
              ),
            ],
            _section('Amount range'),
            Row(
              children: [
                Expanded(
                  child: MoneyField(
                    controller: _min,
                    currency: settings.homeCurrency,
                    label: 'Min',
                    symbol: settings.currencySymbol,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoneyField(
                    controller: _max,
                    currency: settings.homeCurrency,
                    label: 'Max',
                    symbol: settings.currencySymbol,
                  ),
                ),
              ],
            ),
            _section('Date range'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (range != null) {
                        setState(
                          () => _draft = _draft.copyWith(
                            from: range.start,
                            to: range.end,
                          ),
                        );
                      }
                    },
                    child: Text(
                      _draft.from == null
                          ? 'Any dates'
                          : '${_d(_draft.from!)} – ${_d(_draft.to!)}',
                    ),
                  ),
                ),
                if (_draft.from != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(
                      () => _draft = _draft.copyWith(clearDates: true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _apply, child: const Text('Apply filters')),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.labelLarge),
  );
}

String _d(DateTime d) => '${d.day}/${d.month}';

String _typeLabel(TxType t) => switch (t) {
  TxType.expense => 'Expense',
  TxType.income => 'Income',
  TxType.transfer => 'Transfer',
  TxType.adjustment => 'Adjustment',
};

extension<T> on Set<T> {
  // A (value, isOn) toggle reads naturally positionally.
  // ignore: avoid_positional_boolean_parameters
  void toggle(T value, bool on) {
    if (on) {
      add(value);
    } else {
      remove(value);
    }
  }
}
