import 'package:drift/drift.dart';
import 'package:ledgr/core/db/connection.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/db/seed.dart';
import 'package:ledgr/core/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Tags,
    TransactionTags,
    Attachments,
    Budgets,
    RecurringRules,
    Debts,
    DebtPayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedDefaults(this);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Derived account balance in minor units (ADR-0003): opening balance plus
  /// the signed effect of every non-deleted transaction. Adjustments fold in
  /// by M1 once their signed representation lands; M0 covers income, expense,
  /// transfer, and transfer fees.
  Future<int> balanceMinor(int accountId) async {
    final acc = Variable<int>(accountId);
    final income = Variable<int>(TxType.income.index);
    final expense = Variable<int>(TxType.expense.index);
    final transfer = Variable<int>(TxType.transfer.index);
    final row = await customSelect(
      '''
      SELECT
        (SELECT opening_balance_minor FROM accounts WHERE id = ?)
        + COALESCE((SELECT SUM(amount_minor) FROM transactions
            WHERE deleted_at IS NULL AND account_id = ? AND type = ?), 0)
        - COALESCE((SELECT SUM(amount_minor) FROM transactions
            WHERE deleted_at IS NULL AND account_id = ? AND type = ?), 0)
        - COALESCE((SELECT SUM(fee_minor) FROM transactions
            WHERE deleted_at IS NULL AND account_id = ?), 0)
        - COALESCE((SELECT SUM(amount_minor) FROM transactions
            WHERE deleted_at IS NULL AND account_id = ? AND type = ?), 0)
        + COALESCE((SELECT SUM(amount_minor) FROM transactions
            WHERE deleted_at IS NULL AND to_account_id = ? AND type = ?), 0)
        AS balance
      ''',
      variables: [
        acc, // opening
        acc, income, // income in
        acc, expense, // expense out
        acc, // fees out
        acc, transfer, // transfer out
        acc, transfer, // transfer in
      ],
      readsFrom: {accounts, transactions},
    ).getSingle();
    return row.read<int>('balance');
  }
}
