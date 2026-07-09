import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming')),
      body: upcomingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.calendarCheck,
              title: 'Nothing upcoming',
              message: 'Recurring rules due in the next 30 days show here.',
            );
          }
          return ListView(
            children: [
              for (final item in items)
                ListTile(
                  leading: IconBadge(
                    icon: LucideIcons.clock,
                    color: item.isOverdue ? scheme.expense : scheme.primary,
                    iconSize: 18,
                  ),
                  title: Text(item.rule.title),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(item.date)}'
                    '${item.isOverdue ? ' · Overdue' : ''}',
                    style: item.isOverdue
                        ? TextStyle(color: scheme.expense)
                        : null,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AmountText(
                        Money(minor: item.rule.amountMinor, currency: currency),
                        formatter: formatter,
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(recurringRepositoryProvider)
                              .markPaid(item.rule);
                          ref.invalidate(upcomingProvider);
                        },
                        child: const Text('Add'),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.skipForward, size: 18),
                        tooltip: 'Skip',
                        onPressed: () async {
                          await ref
                              .read(recurringRepositoryProvider)
                              .skip(item.rule);
                          ref.invalidate(upcomingProvider);
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
