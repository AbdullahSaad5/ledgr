import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/backup/data/backup_service.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/reports/data/reports_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

/// The app's conscience: the full money path end to end, then a backup
/// round-trip must leave every number identical (PLAN.md §9).
void main() {
  test(
    'accounts → transactions → budget → reports → backup → restore',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final resolver = PeriodResolver(1);
      final july = resolver.ofAnchor(2026, 7);
      final accounts = AccountRepository(db);
      final tx = TransactionRepository(db);
      final budgets = BudgetRepository(db);
      final reports = ReportsRepository(db, resolver);
      final backup = BackupService(db);

      // Onboarding-equivalent: two accounts with opening balances.
      final cash = await accounts.create(
        name: 'Cash',
        type: AccountType.cash,
        icon: 'payments',
        color: 0xFF43A047,
        currency: 'PKR',
        openingBalanceMinor: 500000,
      );
      final bank = await accounts.create(
        name: 'Bank',
        type: AccountType.bank,
        icon: 'account_balance',
        color: 0xFF1565C0,
        currency: 'PKR',
      );

      // A mix of transactions in July.
      await tx.create(
        TransactionDraft(
          type: TxType.expense,
          amountMinor: 15000,
          currency: 'PKR',
          accountId: cash,
          categoryId: 1,
          date: DateTime(2026, 7, 10),
          payee: 'Cafe',
        ),
      );
      await tx.create(
        TransactionDraft(
          type: TxType.income,
          amountMinor: 300000,
          currency: 'PKR',
          accountId: bank,
          categoryId: 19,
          date: DateTime(2026, 7, 5),
        ),
      );
      await tx.create(
        TransactionDraft(
          type: TxType.transfer,
          amountMinor: 50000,
          currency: 'PKR',
          accountId: cash,
          toAccountId: bank,
          feeMinor: 500,
          date: DateTime(2026, 7, 12),
        ),
      );
      await budgets.create(limitMinor: 100000);

      // Snapshot every number that matters.
      Future<Map<String, int>> snapshot() async {
        final totals = await reports.monthTotals(july);
        return {
          'cash': await accounts.balance(cash),
          'bank': await accounts.balance(bank),
          'income': totals.incomeMinor,
          'expense': totals.expenseMinor,
          'netWorth': await reports.netWorthAsOf(DateTime(2026, 7, 31)),
          'spent': await budgets.spentFor(
            await db.select(db.budgets).getSingle(),
            july,
          ),
        };
      }

      final before = await snapshot();

      // Sanity: hand-computed values.
      expect(before['cash'], 500000 - 15000 - 50000 - 500); // 434500
      expect(before['bank'], 300000 + 50000); // 350000
      expect(before['income'], 300000);
      expect(before['expense'], 15000);
      expect(before['netWorth'], 434500 + 350000); // 784500
      expect(before['spent'], 15000);

      // Backup → wipe → restore.
      final json = await backup.export();
      await db.transaction(() async {
        await db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in db.allTables) {
          await db.delete(table).go();
        }
      });
      expect(await db.select(db.accounts).get(), isEmpty);

      await backup.import(json);

      // Every number is identical after the round-trip.
      expect(await snapshot(), before);
    },
  );
}
