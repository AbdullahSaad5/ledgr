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

  String _accountName(List<Account> accounts, int? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return 'Choose';
  }

  Future<void> _editPayee() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _PayeeSheet(initial: _payee.text),
    );
    if (result == null) return;
    _payee.text = result;
    setState(() {});
    if (result.isNotEmpty && _type != TxType.transfer && _categoryId == null) {
      final category = await ref
          .read(transactionRepositoryProvider)
          .commonCategoryForPayee(result);
      if (category != null && mounted) {
        setState(() => _categoryId = category);
      }
    }
  }

  Future<void> _editTags() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _TagsSheet(
        selected: _tagIds,
        onToggle: (id, on) => setState(() {
          if (on) {
            _tagIds.add(id);
          } else {
            _tagIds.remove(id);
          }
        }),
      ),
    );
    setState(() {});
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
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MetaPill(
                            icon: LucideIcons.store,
                            label: _payee.text.trim().isEmpty
                                ? 'Add payee'
                                : _payee.text.trim(),
                            active: _payee.text.trim().isNotEmpty,
                            onTap: _editPayee,
                          ),
                          const SizedBox(width: 8),
                          _MetaPill(
                            icon: LucideIcons.tag,
                            label: _tagIds.isEmpty
                                ? 'Tags'
                                : 'Tags (${_tagIds.length})',
                            active: _tagIds.isNotEmpty,
                            onTap: _editTags,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _SelectorTile(
                      icon: LucideIcons.wallet,
                      label: _type == TxType.transfer ? 'From' : 'Account',
                      value: _accountName(accounts, _accountId),
                      onTap: () async {
                        final id = await _pickAccount(context, accounts);
                        if (id != null) setState(() => _accountId = id);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_type == TxType.transfer)
                    Expanded(
                      child: _SelectorTile(
                        icon: LucideIcons.arrowRight,
                        label: 'To',
                        value: _toAccountId == null
                            ? 'Choose'
                            : _accountName(accounts, _toAccountId),
                        onTap: () async {
                          final id = await _pickAccount(
                            context,
                            accounts.where((a) => a.id != _accountId).toList(),
                          );
                          if (id != null) setState(() => _toAccountId = id);
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: _SelectorTile(
                        icon: LucideIcons.shapes,
                        label: 'Category',
                        value: _categoryId == null
                            ? 'Choose'
                            : ref
                                      .watch(categoryMapProvider)[_categoryId]
                                      ?.name ??
                                  'Choose',
                        onTap: () async {
                          final kind = _type == TxType.income
                              ? CategoryKind.income
                              : CategoryKind.expense;
                          final id = await _pickCategory(context, ref, kind);
                          if (id != null) setState(() => _categoryId = id);
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SelectorTile(
                      icon: LucideIcons.calendar,
                      label: 'Date',
                      value: _dateLabel(_date),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ),
                ],
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

/// A labelled selector tile (Account / Category / Date) above the keypad.
class _SelectorTile extends StatelessWidget {
  const _SelectorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Material(
      color: scheme.surfaceContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small ghost pill under the amount (payee / tags entry points).
class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(99),
    );
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: active
          ? scheme.primary.withValues(alpha: 0.10)
          : scheme.surfaceContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for entering a payee, with live suggestions.
class _PayeeSheet extends ConsumerStatefulWidget {
  const _PayeeSheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_PayeeSheet> createState() => _PayeeSheetState();
}

class _PayeeSheetState extends ConsumerState<_PayeeSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  List<String> _suggestions = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _update(String query) async {
    final suggestions = await ref
        .read(transactionRepositoryProvider)
        .payeeSuggestions(query);
    if (mounted) setState(() => _suggestions = suggestions);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payee', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Who was this with?'),
            onChanged: _update,
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _suggestions.take(6))
                  ActionChip(
                    label: Text(s),
                    onPressed: () => Navigator.of(context).pop(s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_controller.text.trim()),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for toggling and creating tags.
class _TagsSheet extends ConsumerStatefulWidget {
  const _TagsSheet({required this.selected, required this.onToggle});

  final Set<int> selected;
  // A (tagId, isSelected) callback reads naturally positionally.
  // ignore: avoid_positional_boolean_parameters
  final void Function(int id, bool on) onToggle;

  @override
  ConsumerState<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends ConsumerState<_TagsSheet> {
  final _newTag = TextEditingController();

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newTag.text.trim();
    if (name.isEmpty) return;
    final tag = await ref.read(tagRepositoryProvider).getOrCreate(name);
    widget.onToggle(tag.id, true);
    _newTag.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(allTagsProvider).valueOrNull ?? const [];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  FilterChip(
                    label: Text(t.name),
                    selected: widget.selected.contains(t.id),
                    onSelected: (on) {
                      widget.onToggle(t.id, on);
                      setState(() {});
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _newTag,
            decoration: const InputDecoration(hintText: 'New tag name'),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
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
    useRootNavigator: true,
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
  // The sheet must watch the provider itself: a one-shot read before the
  // stream's first emission returns loading and the sheet stays empty forever.
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final categoriesAsync = ref.watch(categoriesByKindProvider(kind));
          return categoriesAsync.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 180,
              child: Center(child: Text('Could not load categories: $e')),
            ),
            data: (categories) => GridView.count(
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
                          // Grid cells are narrow; a capped scale keeps
                          // long names ("Entertainment") from breaking
                          // mid-word at large system font sizes.
                          textScaler: MediaQuery.textScalerOf(
                            context,
                          ).clamp(maxScaleFactor: 1.1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
