import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_select.dart';
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
    final scheme = Theme.of(context).colorScheme;
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
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
        children: [
          GroupCard(
            title: 'Details',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.sm,
                ),
                child: TextField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Rent, Netflix, salary…',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.sm,
                  Gaps.lg,
                  Gaps.lg,
                ),
                child: _TypeSelector(
                  type: _type,
                  onChanged: (t) => setState(() {
                    _type = t;
                    _categoryId = null;
                  }),
                ),
              ),
            ],
          ),
          GroupCard(
            title: 'Money',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.sm,
                ),
                child: MoneyField(
                  controller: _amount,
                  currency: settings.homeCurrency,
                  label: 'Amount',
                  symbol: settings.currencySymbol,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gaps.lg,
                  vertical: Gaps.sm,
                ),
                child: LedgrSelect<int?>(
                  label: 'Account',
                  value: _accountId,
                  options: [
                    for (final a in accounts)
                      LedgrSelectOption(
                        value: a.id,
                        label: a.name,
                        icon: AppIcons.resolve(a.icon),
                        iconColor: Color(a.color),
                      ),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.sm,
                  Gaps.lg,
                  Gaps.lg,
                ),
                child: LedgrSelect<int?>(
                  label: 'Category',
                  value: _categoryId,
                  options: [
                    for (final c in categories)
                      LedgrSelectOption(
                        value: c.id,
                        // Children read as "Parent > Child" in the flat list.
                        label: c.parentId == null
                            ? c.name
                            : '${_nameOf(categories, c.parentId!)} > ${c.name}',
                        icon: AppIcons.resolve(c.icon),
                        iconColor: Color(c.color),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
            ],
          ),
          GroupCard(
            title: 'Schedule',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.sm,
                ),
                child: LedgrSelect<Frequency>(
                  label: 'Repeats',
                  value: _frequency,
                  options: [
                    for (final f in Frequency.values)
                      LedgrSelectOption(
                        value: f,
                        label: _freqLabel(f),
                        icon: LucideIcons.repeat,
                      ),
                  ],
                  onChanged: (v) => setState(() => _frequency = v),
                ),
              ),
              ListTile(
                leading: IconBadge(
                  icon: LucideIcons.calendar,
                  color: scheme.primary,
                  size: 40,
                  iconSize: 18,
                ),
                title: const Text('First occurrence'),
                subtitle: Text(
                  DateFormat('EEE, d MMM yyyy').format(_startDate),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
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
                secondary: IconBadge(
                  icon: LucideIcons.zap,
                  color: scheme.primary,
                  size: 40,
                  iconSize: 18,
                ),
                title: const Text('Post automatically'),
                subtitle: const Text('Off = remind me to add it'),
                value: _autoPost,
                onChanged: (v) => setState(() => _autoPost = v),
              ),
            ],
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

/// Expense/income pill, matching the add-transaction type selector.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onChanged});

  final TxType type;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        children: [
          _segment(
            context,
            label: 'Expense',
            selected: type == TxType.expense,
            accent: scheme.expense,
            onTap: () => onChanged(TxType.expense),
          ),
          _segment(
            context,
            label: 'Income',
            selected: type == TxType.income,
            accent: scheme.income,
            onTap: () => onChanged(TxType.income),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: ShapeDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : null,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? accent : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _nameOf(List<Category> categories, int id) {
  final matches = categories.where((c) => c.id == id);
  return matches.isEmpty ? '?' : matches.first.name;
}

String _freqLabel(Frequency f) => switch (f) {
  Frequency.daily => 'Daily',
  Frequency.weekly => 'Weekly',
  Frequency.monthly => 'Monthly',
  Frequency.yearly => 'Yearly',
};
