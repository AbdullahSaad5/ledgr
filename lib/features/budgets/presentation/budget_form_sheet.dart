import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Create or edit a budget (overall or per category), as a full screen.
/// (Kept as `BudgetFormSheet` with a `show` entry point so call sites are
/// unchanged; it now pushes a full-screen dialog route.)
class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({this.budget, super.key});

  final Budget? budget;

  static Future<void> show(BuildContext context, {Budget? budget}) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BudgetFormSheet(budget: budget),
      ),
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
    // Budgets attach to top-level categories only; a parent budget already
    // counts subcategory spend (#16), so listing children here would create
    // confusing double-cover.
    final categories =
        (ref
                    .watch(categoriesByKindProvider(CategoryKind.expense))
                    .valueOrNull ??
                const <Category>[])
            .where((c) => c.parentId == null)
            .toList();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isEditing ? 'Edit budget' : 'New budget'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, 24),
        children: [
          if (!_isEditing)
            RadioGroup<bool>(
              groupValue: _overall,
              onChanged: (v) => setState(() => _overall = v ?? true),
              child: const GroupCard(
                title: 'What to limit',
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text('Overall'),
                    subtitle: Text('All spending in the month'),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text('Category'),
                    subtitle: Text('One category only'),
                  ),
                ],
              ),
            ),
          if (!_isEditing && !_overall)
            GroupCard(
              title: 'Category',
              children: [
                SizedBox(
                  height: 260,
                  child: GridView.count(
                    crossAxisCount: 4,
                    padding: const EdgeInsets.all(Gaps.md),
                    children: [
                      for (final c in categories)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _categoryId = c.id),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Selected = filled badge + ring + check dot.
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(2),
                                    decoration: ShapeDecoration(
                                      shape: RoundedSuperellipseBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: _categoryId == c.id
                                            ? BorderSide(
                                                color: Color(c.color),
                                                width: 2,
                                              )
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: _categoryId == c.id
                                        ? IconBadge.filled(
                                            icon: AppIcons.resolve(c.icon),
                                            fill: Color(c.color),
                                            onColor: Colors.white,
                                            size: 40,
                                            iconSize: 18,
                                          )
                                        : IconBadge(
                                            icon: AppIcons.resolve(c.icon),
                                            color: Color(c.color),
                                            size: 40,
                                            iconSize: 18,
                                          ),
                                  ),
                                  if (_categoryId == c.id)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: scheme.primary,
                                          border: Border.all(
                                            color: scheme.surface,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          LucideIcons.check,
                                          size: 11,
                                          color: scheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.name,
                                style: text.labelSmall?.copyWith(
                                  fontWeight: _categoryId == c.id
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: _categoryId == c.id
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // Narrow grid cells; cap the scale so long
                                // names don't truncate hard at large system
                                // font sizes.
                                textScaler: MediaQuery.textScalerOf(
                                  context,
                                ).clamp(maxScaleFactor: 1.1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          GroupCard(
            title: 'Limit',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: MoneyField(
                  controller: _limit,
                  currency: settings.homeCurrency,
                  label: 'Monthly limit',
                  symbol: settings.currencySymbol,
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
            child: Text(_isEditing ? 'Save' : 'Create budget'),
          ),
        ),
      ),
    );
  }
}
