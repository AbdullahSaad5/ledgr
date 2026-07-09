import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/color_swatches.dart';
import 'package:ledgr/core/widgets/money_field.dart';

/// Create or edit an account. Presented as a modal bottom sheet.
class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({this.account, super.key});

  final Account? account;

  static Future<void> show(BuildContext context, {Account? account}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AccountFormSheet(account: account),
    );
  }

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late final TextEditingController _creditLimit;
  late AccountType _type;
  late String _icon;
  late int _color;
  late bool _includeInNetWorth;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _opening = TextEditingController(
      text: a == null ? '' : a.openingBalance.toDecimal().toString(),
    );
    _creditLimit = TextEditingController(
      text: a?.creditLimit?.toDecimal().toString() ?? '',
    );
    _type = a?.type ?? AccountType.cash;
    _icon = a?.icon ?? AppIcons.defaultForAccount(_type);
    _color = a?.color ?? AppColors.swatches.first;
    _includeInNetWorth = a?.includeInNetWorth ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final settings = ref.read(appSettingsProvider);
    final repo = ref.read(accountRepositoryProvider);
    final currency = widget.account?.currency ?? settings.homeCurrency;
    final creditLimitMinor =
        _type == AccountType.creditCard && _creditLimit.text.trim().isNotEmpty
        ? MoneyField.parse(_creditLimit.text, currency).minor
        : null;

    if (_isEditing) {
      await repo.update(
        widget.account!.id,
        name: name,
        type: _type,
        icon: _icon,
        color: _color,
        creditLimitMinor: creditLimitMinor,
        includeInNetWorth: _includeInNetWorth,
      );
    } else {
      await repo.create(
        name: name,
        type: _type,
        icon: _icon,
        color: _color,
        currency: currency,
        openingBalanceMinor: MoneyField.parse(_opening.text, currency).minor,
        creditLimitMinor: creditLimitMinor,
        includeInNetWorth: _includeInNetWorth,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final currency = widget.account?.currency ?? settings.homeCurrency;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit account' : 'New account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
              ],
              onChanged: (t) => setState(() {
                _type = t!;
                _icon = AppIcons.defaultForAccount(t);
              }),
            ),
            const SizedBox(height: 16),
            _IconPickerRow(
              selected: _icon,
              onSelected: (i) => setState(() => _icon = i),
            ),
            const SizedBox(height: 16),
            ColorSwatchPicker(
              selected: _color,
              onSelected: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 16),
            if (!_isEditing)
              MoneyField(
                controller: _opening,
                currency: currency,
                label: 'Opening balance',
                symbol: settings.currencySymbol,
              ),
            if (_type == AccountType.creditCard) ...[
              const SizedBox(height: 16),
              MoneyField(
                controller: _creditLimit,
                currency: currency,
                label: 'Credit limit (optional)',
                symbol: settings.currencySymbol,
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in net worth'),
              value: _includeInNetWorth,
              onChanged: (v) => setState(() => _includeInNetWorth = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save' : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(AccountType t) => switch (t) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.creditCard => 'Credit card',
  AccountType.wallet => 'Mobile wallet',
  AccountType.savings => 'Savings',
  AccountType.investment => 'Investment',
  AccountType.other => 'Other',
};

class _IconPickerRow extends StatelessWidget {
  const _IconPickerRow({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppIcons.accountPickerNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final name = AppIcons.accountPickerNames[i];
          final isSelected = name == selected;
          return GestureDetector(
            onTap: () => onSelected(name),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: isSelected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              child: Icon(
                AppIcons.resolve(name),
                color: isSelected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}
