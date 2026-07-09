import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/features/recurring/presentation/recurring_form_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(activeRulesProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendarClock, size: 20),
            tooltip: 'Upcoming',
            onPressed: () => context.push('/upcoming'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RecurringFormSheet.show(context),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Rule'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.repeat,
              title: 'No recurring rules',
              message: 'Automate rent, salary, subscriptions, and more.',
            );
          }
          return ListView(
            children: [
              for (final r in rules)
                ListTile(
                  leading: IconBadge(
                    icon: r.autoPost ? LucideIcons.refreshCw : LucideIcons.bell,
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 18,
                  ),
                  title: Text(r.title),
                  subtitle: Text(
                    'Next ${DateFormat.yMMMd().format(r.nextDue)} · '
                    '${r.autoPost ? 'Auto' : 'Remind'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AmountText(
                        Money(minor: r.amountMinor, currency: currency),
                        formatter: formatter,
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        onPressed: () =>
                            ref.read(recurringRepositoryProvider).delete(r.id),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
    );
  }
}
