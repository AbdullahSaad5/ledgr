import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/reports/data/csv_exporter.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  test('CSV has a header and one escaped row per transaction', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final account = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
    final tx = TransactionRepository(db);
    await tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: 15050,
        currency: 'PKR',
        accountId: account,
        categoryId: 1,
        date: DateTime(2026, 7, 10),
        payee: 'Cafe, Downtown', // contains a comma -> must be quoted
      ),
    );

    final rows = await tx
        .watchInPeriod(PeriodResolver(1).ofAnchor(2026, 7))
        .first;

    final csv = CsvExporter.transactionsToCsv(
      rows,
      accountNames: {account: 'Cash'},
      categoryNames: {1: 'Food & Dining'},
      formatAmount: (m) => (m / 100).toStringAsFixed(2),
    );

    final lines = csv.trim().split('\n');
    expect(lines.first, 'Date,Type,Amount,Account,Category,Payee,Note');
    expect(lines.length, 2);
    expect(lines[1], contains('2026-07-10'));
    expect(lines[1], contains('150.50'));
    expect(lines[1], contains('"Cafe, Downtown"')); // quoted
  });
}
