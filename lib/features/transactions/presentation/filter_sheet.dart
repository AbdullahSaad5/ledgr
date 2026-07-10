import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full filter editor for the search screen. Fixed-height sheet with the
/// Apply button always pinned at the bottom (it used to hide below the fold).
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: const FilterSheet(),
      ),
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

  void _toggleCategory(int id, {required bool on}) {
    setState(() {
      _draft = _draft.copyWith(
        categoryIds: {..._draft.categoryIds}..toggle(id, on),
      );
    });
  }

  /// Parents first, each followed by its children, matching the picker.
  List<Category> _ordered(List<Category> categories) {
    final childrenOf = <int, List<Category>>{};
    for (final c in categories) {
      final p = c.parentId;
      if (p != null) childrenOf.putIfAbsent(p, () => []).add(c);
    }
    return [
      for (final parent in categories.where((c) => c.parentId == null)) ...[
        parent,
        ...childrenOf[parent.id] ?? const <Category>[],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final expense =
        ref.watch(categoriesByKindProvider(CategoryKind.expense)).valueOrNull ??
        const <Category>[];
    final income =
        ref.watch(categoriesByKindProvider(CategoryKind.income)).valueOrNull ??
        const <Category>[];
    final tags = ref.watch(allTagsProvider).valueOrNull ?? const [];
    final settings = ref.watch(appSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.sm, 0),
          child: Row(
            children: [
              Expanded(child: Text('Filters', style: text.titleLarge)),
              TextButton.icon(
                onPressed: () {
                  ref.read(transactionFilterProvider.notifier).state =
                      const TransactionFilter();
                  Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 15),
                label: const Text('Clear all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.xs,
              Gaps.page,
              Gaps.xl,
            ),
            children: [
              _section('Type'),
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                children: [
                  for (final t in TxType.values)
                    _FilterPill(
                      label: _typeLabel(t),
                      icon: _typeIcon(t),
                      iconColor: _typeColor(t, scheme),
                      selected: _draft.types.contains(t),
                      onTap: () => setState(() {
                        _draft = _draft.copyWith(
                          types: {..._draft.types}
                            ..toggle(t, !_draft.types.contains(t)),
                        );
                      }),
                    ),
                ],
              ),
              _section('Accounts'),
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                children: [
                  for (final a in accounts)
                    _FilterPill(
                      label: a.name,
                      icon: AppIcons.resolve(a.icon),
                      iconColor: Color(a.color),
                      selected: _draft.accountIds.contains(a.id),
                      onTap: () => setState(() {
                        _draft = _draft.copyWith(
                          accountIds: {..._draft.accountIds}
                            ..toggle(a.id, !_draft.accountIds.contains(a.id)),
                        );
                      }),
                    ),
                ],
              ),
              _section('Expense categories'),
              _categoryWrap(_ordered(expense)),
              _section('Income categories'),
              _categoryWrap(_ordered(income)),
              if (tags.isNotEmpty) ...[
                _section('Tags'),
                Wrap(
                  spacing: Gaps.sm,
                  runSpacing: Gaps.sm,
                  children: [
                    for (final t in tags)
                      _FilterPill(
                        label: t.name,
                        icon: LucideIcons.tag,
                        selected: _draft.tagIds.contains(t.id),
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            tagIds: {..._draft.tagIds}
                              ..toggle(t.id, !_draft.tagIds.contains(t.id)),
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
                  const SizedBox(width: Gaps.md),
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
              InkWell(
                customBorder: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () async {
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gaps.lg,
                    vertical: 14,
                  ),
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainer,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.calendarRange,
                        size: 18,
                        color: _draft.from == null
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                      const SizedBox(width: Gaps.md),
                      Expanded(
                        child: Text(
                          _draft.from == null
                              ? 'Any dates'
                              : '${_d(_draft.from!)} – ${_d(_draft.to!)}',
                          style: text.titleSmall?.copyWith(
                            color: _draft.from == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (_draft.from != null)
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(
                            () => _draft = _draft.copyWith(clearDates: true),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: EdgeInsets.fromLTRB(
            Gaps.page,
            Gaps.sm,
            Gaps.page,
            bottomInset + Gaps.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _apply,
              child: const Text('Apply filters'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryWrap(List<Category> ordered) => Wrap(
    spacing: Gaps.sm,
    runSpacing: Gaps.sm,
    children: [
      for (final c in ordered)
        _FilterPill(
          label: c.name,
          icon: AppIcons.resolve(c.icon),
          iconColor: Color(c.color),
          isChild: c.parentId != null,
          selected: _draft.categoryIds.contains(c.id),
          onTap: () => _toggleCategory(
            c.id,
            on: !_draft.categoryIds.contains(c.id),
          ),
        ),
    ],
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: Gaps.xl, bottom: Gaps.sm),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// Ledgr's take on a filter chip: superellipse pill, colored leading icon,
/// mint fill + check when selected. Subcategories carry an elbow glyph.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.isChild = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool isChild;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(12),
      side: selected
          ? BorderSide(color: scheme.primary, width: 1.5)
          : BorderSide.none,
    );

    return InkWell(
      customBorder: shape,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: ShapeDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainer,
          shape: shape,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChild) ...[
              Icon(
                LucideIcons.cornerDownRight,
                size: 12,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            if (selected) ...[
              Icon(LucideIcons.check, size: 14, color: scheme.primary),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? scheme.onSurfaceVariant),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: text.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _d(DateTime d) => '${d.day}/${d.month}';

String _typeLabel(TxType t) => switch (t) {
  TxType.expense => 'Expense',
  TxType.income => 'Income',
  TxType.transfer => 'Transfer',
  TxType.adjustment => 'Adjustment',
};

IconData _typeIcon(TxType t) => switch (t) {
  TxType.expense => LucideIcons.arrowDownLeft,
  TxType.income => LucideIcons.arrowUpRight,
  TxType.transfer => LucideIcons.arrowLeftRight,
  TxType.adjustment => LucideIcons.slidersHorizontal,
};

Color _typeColor(TxType t, ColorScheme scheme) => switch (t) {
  TxType.expense => scheme.expense,
  TxType.income => scheme.income,
  TxType.transfer => scheme.primary,
  TxType.adjustment => scheme.onSurfaceVariant,
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
