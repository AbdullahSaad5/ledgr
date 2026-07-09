import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/keypad_controller.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/presentation/widgets/calc_keypad.dart';

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
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Column(
        children: [
          _TypeSelector(
            type: _type,
            onChanged: (t) => setState(() {
              _type = t;
              if (t != TxType.transfer) _toAccountId = null;
            }),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (expressionActive)
                          Text(
                            _keypad.expression,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        FittedBox(
                          child: Text(
                            formatter.format(amount),
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(fontFeatures: const []),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ChipsRow(
                    type: _type,
                    accounts: accounts,
                    accountId: _accountId,
                    toAccountId: _toAccountId,
                    categoryId: _categoryId,
                    date: _date,
                    onPickAccount: (id) => setState(() => _accountId = id),
                    onPickToAccount: (id) => setState(() => _toAccountId = id),
                    onPickCategory: (id) => setState(() => _categoryId = id),
                    onPickDate: (d) => setState(() => _date = d),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _payee,
                      onChanged: _updatePayeeSuggestions,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.store_outlined),
                        hintText: 'Payee (optional)',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _TagRow(
                    selected: _tagIds,
                    onToggle: (id, on) => setState(() {
                      if (on) {
                        _tagIds.add(id);
                      } else {
                        _tagIds.remove(id);
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 300,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CalcKeypad(
                controller: _keypad,
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ],
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
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
            avatar: const Icon(Icons.add, size: 18),
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<TxType>(
        segments: const [
          ButtonSegment(value: TxType.expense, label: Text('Expense')),
          ButtonSegment(value: TxType.income, label: Text('Income')),
          ButtonSegment(value: TxType.transfer, label: Text('Transfer')),
        ],
        selected: {type},
        onSelectionChanged: (s) => onChanged(s.first),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.account_balance_wallet, size: 18),
            label: Text(_accountName(accountId)),
            onPressed: () async {
              final id = await _pickAccount(context, accounts);
              if (id != null) onPickAccount(id);
            },
          ),
          const SizedBox(width: 8),
          if (type == TxType.transfer) ...[
            const Icon(Icons.arrow_forward, size: 16),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
              ),
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
              avatar: const Icon(Icons.category_outlined, size: 18),
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
            avatar: const Icon(Icons.event, size: 18),
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
              leading: CircleAvatar(
                backgroundColor: Color(a.color),
                child: Icon(
                  AppIcons.resolve(a.icon),
                  color: Colors.white,
                  size: 20,
                ),
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
                  CircleAvatar(
                    backgroundColor: Color(c.color).withValues(alpha: 0.2),
                    child: Icon(
                      AppIcons.resolve(c.icon),
                      color: Color(c.color),
                    ),
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
