import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/color_swatches.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_field.dart';
import 'package:ledgr/core/widgets/ledgr_select.dart';
import 'package:ledgr/core/widgets/money_field.dart';

/// Create or edit an account, as a full screen with a live preview card.
/// (Kept as `AccountFormSheet` with a `show` entry point so call sites are
/// unchanged; it now pushes a full-screen dialog route.)
class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({this.account, super.key});

  final Account? account;

  static Future<void> show(BuildContext context, {Account? account}) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AccountFormSheet(account: account),
      ),
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
    _name.addListener(() => setState(() {}));
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = Color(_color);
    final isDark = scheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isEditing ? 'Edit account' : 'New account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, 24),
        children: [
          // Live preview of the account card being built.
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(Gaps.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.16 : 0.10),
                    accent.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconBadge(
                    icon: AppIcons.resolve(_icon),
                    size: 44,
                    iconSize: 20,
                    background: accent.withValues(alpha: isDark ? 0.28 : 0.16),
                    color: isDark
                        ? Color.lerp(accent, Colors.white, 0.35)!
                        : Color.lerp(accent, Colors.black, 0.25)!,
                  ),
                  const SizedBox(width: Gaps.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.text.trim().isEmpty
                            ? 'Account name'
                            : _name.text.trim(),
                        style: text.titleMedium?.copyWith(
                          color: _name.text.trim().isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                      Text(
                        _typeLabel(_type),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GroupCard(
            title: 'Details',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: Column(
                  children: [
                    LedgrField(
                      controller: _name,
                      label: 'Name',
                      hint: 'e.g. Wallet cash, HBL account',
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Gaps.md),
                    LedgrSelect<AccountType>(
                      label: 'Type',
                      value: _type,
                      options: [
                        for (final t in AccountType.values)
                          LedgrSelectOption(
                            value: t,
                            label: _typeLabel(t),
                            icon: AppIcons.resolve(
                              AppIcons.defaultForAccount(t),
                            ),
                          ),
                      ],
                      onChanged: (t) => setState(() {
                        _type = t;
                        _icon = AppIcons.defaultForAccount(t);
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          GroupCard(
            title: 'Style',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconPickerRow(
                      selected: _icon,
                      accent: accent,
                      onSelected: (i) => setState(() => _icon = i),
                    ),
                    const SizedBox(height: Gaps.lg),
                    ColorSwatchPicker(
                      selected: _color,
                      onSelected: (c) => setState(() => _color = c),
                    ),
                  ],
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
                child: Column(
                  children: [
                    if (!_isEditing)
                      MoneyField(
                        controller: _opening,
                        currency: currency,
                        label: 'Opening balance',
                        symbol: settings.currencySymbol,
                      ),
                    if (_type == AccountType.creditCard) ...[
                      const SizedBox(height: Gaps.md),
                      MoneyField(
                        controller: _creditLimit,
                        currency: currency,
                        label: 'Credit limit (optional)',
                        symbol: settings.currencySymbol,
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include in net worth'),
                      value: _includeInNetWorth,
                      onChanged: (v) => setState(() => _includeInNetWorth = v),
                    ),
                  ],
                ),
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
          child: FilledButton(
            onPressed: _save,
            child: Text(_isEditing ? 'Save' : 'Create account'),
          ),
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
  const _IconPickerRow({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppIcons.accountPickerNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: Gaps.md),
        itemBuilder: (context, i) {
          final name = AppIcons.accountPickerNames[i];
          final isSelected = name == selected;
          return GestureDetector(
            onTap: () => onSelected(name),
            child: IconBadge(
              icon: AppIcons.resolve(name),
              size: 46,
              iconSize: 20,
              background: isSelected
                  ? accent.withValues(alpha: 0.22)
                  : scheme.surfaceContainer,
              color: isSelected ? accent : scheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
