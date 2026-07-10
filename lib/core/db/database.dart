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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedDefaults(this);
    },
    onUpgrade: (m, from, to) async {
      // v1 stored datetimes as ISO text with a UTC offset, which drift read
      // back as UTC — shifting displayed days for anyone east/west of UTC.
      // v3 stores unix seconds in INTEGER columns (drift's default): values
      // read back in local time and compare numerically. The transform also
      // accepts v2's interim numeric-in-TEXT state.
      if (from < 3) {
        for (final table in <TableInfo<Table, dynamic>>[
          accounts,
          categories,
          transactions,
          tags,
          attachments,
          budgets,
          recurringRules,
          debts,
          debtPayments,
        ]) {
          final dateColumns = table.$columns
              .where(
                (GeneratedColumn<Object> c) => c.type == DriftSqlType.dateTime,
              )
              .toList();
          // TableMigration is drift's supported (if experimental) way to
          // rebuild a table in place; the alternative is hand-written SQL.
          // ignore: experimental_member_use
          await m.alterTable(
            // Same experimental API as above.
            // ignore: experimental_member_use
            TableMigration(
              table,
              columnTransformer: {
                for (final c in dateColumns)
                  c: CustomExpression<DateTime>(
                    "CASE WHEN typeof(${c.name}) = 'text' "
                    "AND ${c.name} GLOB '[0-9]*' "
                    'THEN CAST(${c.name} AS INTEGER) '
                    "WHEN typeof(${c.name}) = 'text' "
                    'THEN unixepoch(${c.name}) '
                    'ELSE ${c.name} END',
                  ),
              },
            ),
          );
        }
      }
      // v4 adds the seeded utility subcategories under Bills & Utilities
      // (#16). seedBillsSubcategories is idempotent and no-ops when the
      // user has deleted or renamed the parent.
      if (from < 4) {
        await seedBillsSubcategories(this);
      }
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

  /// Reactive active accounts joined with their derived balances in ONE
  /// query, so a change to either table re-emits (two combined streams
  /// previously deadlocked on asyncExpand's completion semantics).
  Stream<List<(Account, int)>> watchActiveAccountsWithBalances() {
    final sql = _balanceSelect(
      single: false,
    ).replaceFirst('SELECT accounts.id AS account_id,', 'SELECT accounts.*,');
    return customSelect(
      '$sql AND accounts.archived = 0 ORDER BY accounts.position',
      readsFrom: {accounts, transactions},
    ).watch().map(
      (rows) => [
        for (final r in rows) (accounts.map(r.data), r.read<int>('balance')),
      ],
    );
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
