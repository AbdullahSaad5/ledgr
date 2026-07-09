import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

/// The sole gateway to transaction data (CLAUDE.md rule 6). Deletes are
/// tombstones (ADR-0005); `updatedAt` is touched on every write.
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// Non-deleted transactions whose date falls in [period], newest first.
  Stream<List<Transaction>> watchInPeriod(Period period) {
    return (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.date.isBiggerOrEqualValue(period.start) &
                t.date.isSmallerThanValue(period.end),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Non-deleted transactions touching [accountId] (as source or transfer
  /// target), newest first.
  Stream<List<Transaction>> watchForAccount(int accountId) {
    return (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                (t.accountId.equals(accountId) |
                    t.toAccountId.equals(accountId)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<Transaction> watchById(int id) => (_db.select(
    _db.transactions,
  )..where((t) => t.id.equals(id))).watchSingle();

  Future<int> create(TransactionDraft draft) {
    draft.validate();
    return _db.into(_db.transactions).insert(_companion(draft));
  }

  Future<void> update(int id, TransactionDraft draft) {
    draft.validate();
    return (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(id))).write(_companion(draft, touch: true));
  }

  /// Duplicate an existing transaction, dated now. Returns the new id.
  Future<int> duplicate(int id) async {
    final source = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            type: source.type,
            amountMinor: source.amountMinor,
            currency: source.currency,
            accountId: source.accountId,
            date: DateTime.now(),
            toAccountId: Value(source.toAccountId),
            feeMinor: Value(source.feeMinor),
            categoryId: Value(source.categoryId),
            payee: Value(source.payee),
            note: Value(source.note),
          ),
        );
  }

  /// Soft-delete (tombstone). Reversible with [restore] for undo.
  Future<void> softDelete(int id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restore(int id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  TransactionsCompanion _companion(TransactionDraft d, {bool touch = false}) {
    return TransactionsCompanion(
      type: Value(d.type),
      amountMinor: Value(d.amountMinor),
      currency: Value(d.currency),
      accountId: Value(d.accountId),
      toAccountId: Value(d.toAccountId),
      feeMinor: Value(d.feeMinor),
      categoryId: Value(d.categoryId),
      payee: Value(d.payee),
      note: Value(d.note),
      date: Value(d.date),
      updatedAt: touch ? Value(DateTime.now()) : const Value.absent(),
    );
  }
}
