import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';

/// An account paired with its live derived balance (minor units).
class AccountWithBalance {
  const AccountWithBalance(this.account, this.balanceMinor);
  final Account account;
  final int balanceMinor;
}

/// The sole gateway to account data (CLAUDE.md rule 6). Maintains `updatedAt`
/// on every write and never hard-deletes (archive / tombstone only).
class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  /// Non-archived, non-deleted accounts ordered by position, each with balance.
  Stream<List<AccountWithBalance>> watchActiveWithBalances() {
    final accounts = _activeQuery().watch();
    return _db.watchAllBalances().asyncExpand((balances) {
      return accounts.map(
        (rows) => rows
            .map(
              (a) => AccountWithBalance(
                a,
                balances[a.id] ?? a.openingBalanceMinor,
              ),
            )
            .toList(),
      );
    });
  }

  Stream<List<Account>> watchActive() => _activeQuery().watch();

  Stream<Account> watchById(int id) =>
      (_db.select(_db.accounts)..where((a) => a.id.equals(id))).watchSingle();

  Stream<int> watchBalance(int id) => _db.watchBalanceMinor(id);

  Future<int> balance(int id) => _db.balanceMinor(id);

  Future<int> create({
    required String name,
    required AccountType type,
    required String icon,
    required int color,
    required String currency,
    int openingBalanceMinor = 0,
    int? creditLimitMinor,
    bool includeInNetWorth = true,
  }) async {
    final position = await _nextPosition();
    return _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            icon: icon,
            color: color,
            currency: currency,
            position: position,
            openingBalanceMinor: Value(openingBalanceMinor),
            creditLimitMinor: Value(creditLimitMinor),
            includeInNetWorth: Value(includeInNetWorth),
          ),
        );
  }

  Future<void> update(
    int id, {
    required String name,
    required AccountType type,
    required String icon,
    required int color,
    required bool includeInNetWorth,
    int? creditLimitMinor,
  }) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(name),
        type: Value(type),
        icon: Value(icon),
        color: Value(color),
        creditLimitMinor: Value(creditLimitMinor),
        includeInNetWorth: Value(includeInNetWorth),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setArchived(int id, {required bool archived}) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Persists a manual reorder as compacted positions in one transaction.
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(
          _db.accounts,
        )..where((a) => a.id.equals(orderedIds[i]))).write(
          AccountsCompanion(
            position: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// Reconcile: post an adjustment for `target - current` so the derived
  /// balance matches reality (ADR-0003). Returns the adjustment tx id, or null
  /// when already reconciled.
  Future<int?> reconcile(int accountId, {required int targetMinor}) async {
    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    final current = await _db.balanceMinor(accountId);
    final delta = targetMinor - current;
    if (delta == 0) return null;
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            type: TxType.adjustment,
            amountMinor: delta, // signed delta (adjustment convention)
            currency: account.currency,
            accountId: accountId,
            date: DateTime.now(),
            note: const Value('Balance adjustment'),
          ),
        );
  }

  SimpleSelectStatement<$AccountsTable, Account> _activeQuery() {
    return _db.select(_db.accounts)
      ..where((a) => a.archived.equals(false) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm(expression: a.position)]);
  }

  Future<int> _nextPosition() async {
    final maxPos = _db.accounts.position.max();
    final row = await (_db.selectOnly(
      _db.accounts,
    )..addColumns([maxPos])).getSingle();
    return (row.read(maxPos) ?? -1) + 1;
  }
}
