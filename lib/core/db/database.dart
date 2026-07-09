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

  /// Per-account derived balance (ADR-0003/0004): opening balance plus the
  /// signed effect of every non-deleted transaction, correlated to `accounts`.
  ///
  /// Signs by type: income `+`, expense `-`, transfer `-` from the source and
  /// `+` to the target, transfer fee `-` from the source. **Adjustments** carry
  /// a signed delta directly in `amount_minor` (the one type where the amount
  /// is not stored strictly positive — reconcile writes `target - current`).
  ///
  /// Enum indexes are interpolated (trusted ints from [TxType], never user
  /// input); the account id, when scoping to one, is bound.
  static String _balanceSelect({required bool single}) {
    const income = 'type = $_incomeIdx';
    const expense = 'type = $_expenseIdx';
    const transfer = 'type = $_transferIdx';
    const adjustment = 'type = $_adjustmentIdx';
    const notDeleted = 'deleted_at IS NULL';
    return '''
    SELECT accounts.id AS account_id,
      accounts.opening_balance_minor
      + COALESCE((SELECT SUM(amount_minor) FROM transactions
          WHERE $notDeleted AND account_id = accounts.id AND $income), 0)
      - COALESCE((SELECT SUM(amount_minor) FROM transactions
          WHERE $notDeleted AND account_id = accounts.id AND $expense), 0)
      - COALESCE((SELECT SUM(fee_minor) FROM transactions
          WHERE $notDeleted AND account_id = accounts.id), 0)
      - COALESCE((SELECT SUM(amount_minor) FROM transactions
          WHERE $notDeleted AND account_id = accounts.id AND $transfer), 0)
      + COALESCE((SELECT SUM(amount_minor) FROM transactions
          WHERE $notDeleted AND to_account_id = accounts.id AND $transfer), 0)
      + COALESCE((SELECT SUM(amount_minor) FROM transactions
          WHERE $notDeleted AND account_id = accounts.id AND $adjustment), 0)
      AS balance
    FROM accounts
    WHERE accounts.deleted_at IS NULL${single ? ' AND accounts.id = ?' : ''}
    ''';
  }

  static const _incomeIdx = 1; // TxType.income.index
  static const _expenseIdx = 0; // TxType.expense.index
  static const _transferIdx = 2; // TxType.transfer.index
  static const _adjustmentIdx = 3; // TxType.adjustment.index

  Future<int> balanceMinor(int accountId) async {
    final row = await customSelect(
      _balanceSelect(single: true),
      variables: [Variable<int>(accountId)],
      readsFrom: {accounts, transactions},
    ).getSingle();
    return row.read<int>('balance');
  }

  /// Reactive balance for one account.
  Stream<int> watchBalanceMinor(int accountId) {
    return customSelect(
      _balanceSelect(single: true),
      variables: [Variable<int>(accountId)],
      readsFrom: {accounts, transactions},
    ).watchSingle().map((row) => row.read<int>('balance'));
  }

  /// Reactive balances for every non-archived account, keyed by account id.
  Stream<Map<int, int>> watchAllBalances() {
    return customSelect(
      _balanceSelect(single: false),
      readsFrom: {accounts, transactions},
    ).watch().map(
      (rows) => {
        for (final r in rows) r.read<int>('account_id'): r.read<int>('balance'),
      },
    );
  }
}
