import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/reports/data/csv_exporter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports the selected period's transactions to a CSV file and opens the share
/// sheet.
Future<void> exportPeriodCsv(WidgetRef ref) async {
  final period = ref.read(selectedPeriodProvider);
  final txs = await ref
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
    '${dir.path}/ledgr_${period.anchorYear}_${period.anchorMonth}.csv',
  );
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path)], subject: 'Ledgr export');
}
