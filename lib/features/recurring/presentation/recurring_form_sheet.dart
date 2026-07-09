import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Create a recurring rule.
class RecurringFormSheet extends ConsumerStatefulWidget {
  const RecurringFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const RecurringFormSheet(),
      ),
    );
  }

  @override
  ConsumerState<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<RecurringFormSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  TxType _type = TxType.expense;
  int? _accountId;
  int? _categoryId;
  Frequency _frequency = Frequency.monthly;
  DateTime _startDate = DateTime.now();
  bool _autoPost = true;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final currency = ref.read(appSettingsProvider).homeCurrency;
    final amount = MoneyField.parse(_amount.text, currency).minor;
    final accounts = ref.read(accountsProvider).valueOrNull ?? const [];
    final accountId =
        _accountId ?? (accounts.isEmpty ? null : accounts.first.id);
    if (title.isEmpty || amount <= 0 || accountId == null) return;

    await ref
        .read(recurringRepositoryProvider)
        .create(
          RecurringRulesCompanion.insert(
            title: title,
            type: _type,
            amountMinor: amount,
            currency: currency,
            accountId: accountId,
            frequency: _frequency,
            nextDue: _startDate,
            anchorDay: Value(_startDate.day),
            categoryId: Value(_categoryId),
            autoPost: Value(_autoPost),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final kind = _type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categories =
        ref.watch(categoriesByKindProvider(kind)).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('New recurring'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, 24),
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Title (e.g. Rent, Netflix)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Expense')),
              ButtonSegment(value: TxType.income, label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          MoneyField(
            controller: _amount,
            currency: settings.homeCurrency,
            label: 'Amount',
            symbol: settings.currencySymbol,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _accountId,
            decoration: const InputDecoration(
              labelText: 'Account',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Frequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(
              labelText: 'Frequency',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final f in Frequency.values)
                DropdownMenuItem(value: f, child: Text(_freqLabel(f))),
            ],
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.calendar, size: 18),
            label: Text(
              'Starts ${_startDate.day}/${_startDate.month}/${_startDate.year}',
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Post automatically'),
            subtitle: const Text('Off = remind me to add it'),
            value: _autoPost,
            onChanged: (v) => setState(() => _autoPost = v),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          Gaps.page,
          Gaps.sm,
          Gaps.page,
          Gaps.md,
        ),
        child: SizedBox(
          height: 52,
          child: FilledButton(onPressed: _save, child: const Text('Create')),
        ),
      ),
    );
  }
}

String _freqLabel(Frequency f) => switch (f) {
  Frequency.daily => 'Daily',
  Frequency.weekly => 'Weekly',
  Frequency.monthly => 'Monthly',
  Frequency.yearly => 'Yearly',
};
