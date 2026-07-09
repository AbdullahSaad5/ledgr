import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/keypad_controller.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/presentation/widgets/calc_keypad.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Add or edit a transaction (PLAN.md §6.3). The 5-second path: amount on the
/// keypad, pick a type/account/category, save.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.transactionId, super.key});

  final int? transactionId;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _keypad = KeypadController();
  final _payee = TextEditingController();
  final _note = TextEditingController();

  TxType _type = TxType.expense;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  final Set<int> _tagIds = {};
  List<String> _payeeSuggestions = const [];
  bool _loaded = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadTags();
  }

  @override
  void dispose() {
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final tags = await ref
        .read(tagRepositoryProvider)
        .tagsForTransaction(widget.transactionId!);
    if (mounted) {
      setState(() => _tagIds.addAll(tags.map((t) => t.id)));
    }
  }

  Future<void> _updatePayeeSuggestions(String query) async {
    final repo = ref.read(transactionRepositoryProvider);
    final suggestions = await repo.payeeSuggestions(query);
    if (mounted) {
      setState(
        () => _payeeSuggestions = suggestions
            .where((s) => s != _payee.text)
            .toList(),
      );
    }
  }

  Future<void> _pickPayee(String payee) async {
    _payee.text = payee;
    setState(() => _payeeSuggestions = const []);
    if (_type != TxType.transfer && _categoryId == null) {
      final category = await ref
          .read(transactionRepositoryProvider)
          .commonCategoryForPayee(payee);
      if (category != null && mounted) {
        setState(() => _categoryId = category);
      }
    }
  }

  void _hydrate(Transaction tx) {
    if (_loaded) return;
    _loaded = true;
    _type = tx.type;
    _accountId = tx.accountId;
    _toAccountId = tx.toAccountId;
    _categoryId = tx.categoryId;
    _date = tx.date;
    _payee.text = tx.payee ?? '';
    _note.text = tx.note ?? '';
    _keypad.expression = KeypadController.fromMoney(tx.amount).expression;
  }

  Future<void> _save() async {
    final settings = ref.read(appSettingsProvider);
    final accounts = ref.read(accountsProvider).valueOrNull ?? const [];
    if (_accountId == null || accounts.isEmpty) return;
    final currency = settings.homeCurrency;
    final amount = _keypad.toMoney(currency);
    if (amount.minor <= 0) {
      _toast('Enter an amount');
      return;
    }
    if (_type == TxType.transfer && _toAccountId == null) {
      _toast('Pick a destination account');
      return;
    }

    final draft = TransactionDraft(
      type: _type,
      amountMinor: amount.minor,
      currency: currency,
      accountId: _accountId!,
      toAccountId: _type == TxType.transfer ? _toAccountId : null,
      categoryId: _type == TxType.transfer ? null : _categoryId,
      payee: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      date: _date,
    );

    final repo = ref.read(transactionRepositoryProvider);
    final int id;
    if (_isEditing) {
      await repo.update(widget.transactionId!, draft);
      id = widget.transactionId!;
    } else {
      id = await repo.create(draft);
    }
    await ref.read(tagRepositoryProvider).setTagsForTransaction(id, _tagIds);
    await HapticFeedback.mediumImpact();

    if (draft.type == TxType.expense) {
      final period = ref
          .read(periodResolverProvider)
          .periodContaining(draft.date);
      await ref
          .read(budgetAlertServiceProvider)
          .onExpenseRecorded(
            amountMinor: draft.amountMinor,
            categoryId: draft.categoryId,
            period: period,
          );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final settings = ref.watch(appSettingsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final scheme = Theme.of(context).colorScheme;

    // Hydrate on edit once the row is available.
    if (_isEditing) {
      ref
          .watch(transactionByIdProvider(widget.transactionId!))
          .whenData(_hydrate);
    }

    final accounts = accountsAsync.valueOrNull ?? const <Account>[];
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;

    final amount = _keypad.toMoneyOrZero(settings.homeCurrency);
    final expressionActive = _keypad.expression.contains(RegExp(r'[+\-*/]'));

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isEditing ? 'Edit transaction' : 'New transaction'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TypeSelector(
              type: _type,
              onChanged: (t) => setState(() {
                _type = t;
                if (t != TxType.transfer) _toAccountId = null;
              }),
            ),
            // The amount owns the flexible space, so the layout stays
            // balanced instead of leaving a dead gap above the keypad.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (expressionActive)
                        Text(
                          _keypad.expression,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      FittedBox(
                        child: AnimatedScale(
                          scale: amount.minor == 0 ? 0.96 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            formatter.format(amount),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  color: amount.minor == 0
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Everything the transaction needs, in one aligned card.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: _ChipsRow(
                        type: _type,
                        accounts: accounts,
                        accountId: _accountId,
                        toAccountId: _toAccountId,
                        categoryId: _categoryId,
                        date: _date,
                        onPickAccount: (id) => setState(() => _accountId = id),
                        onPickToAccount: (id) =>
                            setState(() => _toAccountId = id),
                        onPickCategory: (id) =>
                            setState(() => _categoryId = id),
                        onPickDate: (d) => setState(() => _date = d),
                      ),
                    ),
                    if (_payeeSuggestions.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final s in _payeeSuggestions)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(s),
                                  onPressed: () => _pickPayee(s),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _payee,
                        onChanged: _updatePayeeSuggestions,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          icon: Icon(
                            LucideIcons.store,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          hintText: 'Payee (optional)',
                          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _TagRow(
                        selected: _tagIds,
                        onToggle: (id, on) => setState(() {
                          if (on) {
                            _tagIds.add(id);
                          } else {
                            _tagIds.remove(id);
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // While the system keyboard is up (payee/tag entry), the calc
            // keypad and save bar give way instead of stacking under it.
            if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.30).clamp(
                  170.0,
                  264.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CalcKeypad(
                    controller: _keypad,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _SaveButton(onPressed: _save),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width gradient save bar anchored under the keypad.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(18),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: scheme.heroGradient,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: Center(
            child: Text(
              'Save',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.onHero),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({required this.selected, required this.onToggle});

  final Set<int> selected;
  // A (tagId, isSelected) callback reads naturally positionally.
  // ignore: avoid_positional_boolean_parameters
  final void Function(int id, bool on) onToggle;

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New tag',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Tag name'),
              onSubmitted: (v) => Navigator.of(sheetContext).pop(v.trim()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
    if (name != null && name.isNotEmpty) {
      final tag = await ref.read(tagRepositoryProvider).getOrCreate(name);
      onToggle(tag.id, true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider).valueOrNull ?? const [];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final t in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(t.name),
                selected: selected.contains(t.id),
                onSelected: (on) => onToggle(t.id, on),
              ),
            ),
          ActionChip(
            avatar: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Tag'),
            onPressed: () => _createTag(context, ref),
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onChanged});

  final TxType type;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color accentFor(TxType t) => switch (t) {
      TxType.expense => scheme.expense,
      TxType.income => scheme.income,
      _ => scheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: ShapeDecoration(
          color: scheme.surfaceContainer,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            for (final (t, label) in const [
              (TxType.expense, 'Expense'),
              (TxType.income, 'Income'),
              (TxType.transfer, 'Transfer'),
            ])
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: ShapeDecoration(
                      color: t == type
                          ? accentFor(t).withValues(alpha: 0.16)
                          : Colors.transparent,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: t == type
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: t == type
                              ? accentFor(t)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends ConsumerWidget {
  const _ChipsRow({
    required this.type,
    required this.accounts,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.date,
    required this.onPickAccount,
    required this.onPickToAccount,
    required this.onPickCategory,
    required this.onPickDate,
  });

  final TxType type;
  final List<Account> accounts;
  final int? accountId;
  final int? toAccountId;
  final int? categoryId;
  final DateTime date;
  final ValueChanged<int> onPickAccount;
  final ValueChanged<int> onPickToAccount;
  final ValueChanged<int> onPickCategory;
  final ValueChanged<DateTime> onPickDate;

  String _accountName(int? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return 'Account';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryMapProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(LucideIcons.wallet, size: 16),
            label: Text(_accountName(accountId)),
            onPressed: () async {
              final id = await _pickAccount(context, accounts);
              if (id != null) onPickAccount(id);
            },
          ),
          const SizedBox(width: 8),
          if (type == TxType.transfer) ...[
            const Icon(LucideIcons.arrowRight, size: 16),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(LucideIcons.wallet, size: 16),
              label: Text(
                toAccountId == null ? 'To…' : _accountName(toAccountId),
              ),
              onPressed: () async {
                final id = await _pickAccount(
                  context,
                  accounts.where((a) => a.id != accountId).toList(),
                );
                if (id != null) onPickToAccount(id);
              },
            ),
          ] else ...[
            ActionChip(
              avatar: const Icon(LucideIcons.shapes, size: 16),
              label: Text(
                categoryId == null
                    ? 'Category'
                    : categories[categoryId]?.name ?? 'Category',
              ),
              onPressed: () async {
                final kind = type == TxType.income
                    ? CategoryKind.income
                    : CategoryKind.expense;
                final id = await _pickCategory(context, ref, kind);
                if (id != null) onPickCategory(id);
              },
            ),
          ],
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(LucideIcons.calendar, size: 16),
            label: Text(_dateLabel(date)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPickDate(picked);
            },
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${d.day}/${d.month}/${d.year}';
}

Future<int?> _pickAccount(BuildContext context, List<Account> accounts) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final a in accounts)
            ListTile(
              leading: IconBadge(
                icon: AppIcons.resolve(a.icon),
                color: Color(a.color),
                iconSize: 19,
              ),
              title: Text(a.name),
              onTap: () => Navigator.of(context).pop(a.id),
            ),
        ],
      ),
    ),
  );
}

Future<int?> _pickCategory(
  BuildContext context,
  WidgetRef ref,
  CategoryKind kind,
) {
  final categories =
      ref.read(categoriesByKindProvider(kind)).valueOrNull ?? const [];
  return showModalBottomSheet<int>(
    context: context,
    builder: (_) => SafeArea(
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        children: [
          for (final c in categories)
            InkWell(
              onTap: () => Navigator.of(context).pop(c.id),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconBadge(
                    icon: AppIcons.resolve(c.icon),
                    color: Color(c.color),
                    size: 44,
                    iconSize: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.name,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
