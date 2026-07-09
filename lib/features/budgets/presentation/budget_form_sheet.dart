import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/money_field.dart';

/// Create a budget for a category (or overall).
class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({this.budget, super.key});

  final Budget? budget;

  static Future<void> show(BuildContext context, {Budget? budget}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BudgetFormSheet(budget: budget),
    );
  }

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _limit = TextEditingController();
  int? _categoryId; // null = overall
  bool _overall = true;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    if (b != null) {
      _categoryId = b.categoryId;
      _overall = b.categoryId == null;
      final currency = ref.read(appSettingsProvider).homeCurrency;
      final digits = MoneyField.parse('1', currency).decimalDigits;
      var factor = 1;
      for (var i = 0; i < digits; i++) {
        factor *= 10;
      }
      _limit.text = (b.limitMinor / factor).toString();
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currency = ref.read(appSettingsProvider).homeCurrency;
    final limit = MoneyField.parse(_limit.text, currency).minor;
    if (limit <= 0) return;
    final repo = ref.read(budgetRepositoryProvider);
    if (_isEditing) {
      await repo.updateLimit(widget.budget!.id, limit);
    } else {
      await repo.create(
        categoryId: _overall ? null : _categoryId,
        limitMinor: limit,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final categories =
        ref.watch(categoriesByKindProvider(CategoryKind.expense)).valueOrNull ??
        const [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit budget' : 'New budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (!_isEditing) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Overall')),
                ButtonSegment(value: false, label: Text('Category')),
              ],
              selected: {_overall},
              onSelectionChanged: (s) => setState(() => _overall = s.first),
            ),
            const SizedBox(height: 16),
            if (!_overall)
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
          ],
          MoneyField(
            controller: _limit,
            currency: settings.homeCurrency,
            label: 'Monthly limit',
            symbol: settings.currencySymbol,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(_isEditing ? 'Save' : 'Create budget'),
          ),
        ],
      ),
    );
  }
}
