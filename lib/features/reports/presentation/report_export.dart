import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/reports/data/csv_exporter.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports transactions to a CSV file and opens the share sheet — either the
/// selected period or everything (#17 gap fix).
Future<void> exportPeriodCsv(WidgetRef ref, {bool all = false}) async {
  final period = ref.read(selectedPeriodProvider);
  final txs = all
      ? await ref
            .read(transactionRepositoryProvider)
            .watchFiltered(const TransactionFilter())
            .first
      : await ref
            .read(transactionRepositoryProvider)
            .watchInPeriod(period)
            .first;
  final accounts = ref.read(accountMapProvider);
  final categories = ref.read(categoryMapProvider);
  final formatter = ref.read(moneyFormatterProvider);
  final currency = ref.read(appSettingsProvider).homeCurrency;

  final csv = CsvExporter.transactionsToCsv(
    txs,
    accountNames: {for (final e in accounts.entries) e.key: e.value.name},
    // Subcategories export as "Parent > Child" so the CSV stays unambiguous
    // outside the app (#16).
    categoryNames: {
      for (final e in categories.entries)
        e.key: e.value.parentId == null
            ? e.value.name
            : '${categories[e.value.parentId]?.name ?? '?'} > ${e.value.name}',
    },
    formatAmount: (m) => formatter.format(Money(minor: m, currency: currency)),
  );

  final dir = await getTemporaryDirectory();
  final file = File(
    all
        ? '${dir.path}/ledgr_all_transactions.csv'
        : '${dir.path}/ledgr_${period.anchorYear}_${period.anchorMonth}.csv',
  );
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path)], subject: 'Ledgr export');
}
