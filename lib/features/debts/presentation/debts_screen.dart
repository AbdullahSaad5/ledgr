import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/debts/presentation/debt_form_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Owed to me'),
              Tab(text: 'I owe'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DebtList(direction: DebtDirection.lent),
            _DebtList(direction: DebtDirection.borrowed),
          ],
        ),
      ),
    );
  }
}

class _DebtList extends ConsumerWidget {
  const _DebtList({required this.direction});

  final DebtDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsByDirectionProvider(direction));
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-debt-$direction',
        onPressed: () => DebtFormSheet.show(context, direction),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Debt'),
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (debts) {
          if (debts.isEmpty) {
            return EmptyState(
              icon: LucideIcons.handshake,
              title: direction == DebtDirection.lent
                  ? 'Nobody owes you'
                  : 'You owe nobody',
              message: 'Track money you lent or borrowed here.',
            );
          }
          final outstanding = debts
              .where((d) => !d.debt.settled)
              .fold(0, (s, d) => s + d.remainingMinor);
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    AmountText(
                      Money(minor: outstanding, currency: currency),
                      formatter: formatter,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              for (final d in debts)
                _DebtTile(
                  debt: d,
                  formatter: formatter,
                  currency: currency,
                  onTap: () => _openDetail(context, ref, d),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    DebtWithRemaining debt,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DebtDetailSheet(debt: debt),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.debt,
    required this.formatter,
    required this.currency,
    required this.onTap,
  });

  final DebtWithRemaining debt;
  final MoneyFormatter formatter;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = debt.debt.principalMinor == 0
        ? 0.0
        : (debt.paidMinor / debt.debt.principalMinor).clamp(0.0, 1.0);
    return ListTile(
      onTap: onTap,
      leading: IconBadge(
        icon: LucideIcons.userRound,
        color: debt.isOverdue ? scheme.expense : scheme.primary,
        iconSize: 18,
      ),
      title: Text(debt.debt.person),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: debt.isOverdue ? scheme.expense : scheme.primary,
            ),
          ),
          if (debt.isOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Overdue',
                style: TextStyle(color: scheme.expense, fontSize: 12),
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AmountText(
            Money(minor: debt.remainingMinor, currency: currency),
            formatter: formatter,
          ),
          if (debt.debt.settled)
            const Text('Settled', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DebtDetailSheet extends ConsumerStatefulWidget {
  const _DebtDetailSheet({required this.debt});
  final DebtWithRemaining debt;

  @override
  ConsumerState<_DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends ConsumerState<_DebtDetailSheet> {
  final _amount = TextEditingController();
  int? _accountId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _addPayment() async {
    final currency = widget.debt.debt.currency;
    final amount = MoneyField.parse(_amount.text, currency).minor;
    if (amount <= 0) return;
    await ref
        .read(debtRepositoryProvider)
        .addPayment(widget.debt, amountMinor: amount, accountId: _accountId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final debt = widget.debt;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(debt.debt.person, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Remaining'),
              AmountText(
                Money(minor: debt.remainingMinor, currency: debt.debt.currency),
                formatter: formatter,
              ),
            ],
          ),
          const Divider(height: 24),
          if (!debt.debt.settled) ...[
            MoneyField(
              controller: _amount,
              currency: debt.debt.currency,
              label: 'Repayment amount',
              symbol: settings.currencySymbol,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: 'Account (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(child: Text('Don’t post a transaction')),
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _addPayment,
                    child: const Text('Add payment'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(debtRepositoryProvider).settle(debt.debt.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Settle'),
                ),
              ],
            ),
          ] else
            const Text('This debt is settled.'),
        ],
      ),
    );
  }
}
