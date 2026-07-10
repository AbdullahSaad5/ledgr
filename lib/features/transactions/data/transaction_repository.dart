import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';

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

  /// Transactions matching [filter], newest first. All criteria are ANDed.
  Stream<List<Transaction>> watchFiltered(TransactionFilter filter) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);

    final text = filter.text?.trim();
    if (text != null && text.isNotEmpty) {
      final like = '%${text.toLowerCase()}%';
      query.where(
        (t) => t.payee.lower().like(like) | t.note.lower().like(like),
      );
    }
    if (filter.accountIds.isNotEmpty) {
      query.where(
        (t) =>
            t.accountId.isIn(filter.accountIds) |
            t.toAccountId.isIn(filter.accountIds),
      );
    }
    if (filter.categoryIds.isNotEmpty) {
      // Selecting a parent also matches its subcategories (#16): the
      // subquery pulls in every category whose parent is in the filter.
      final childSub = _db.selectOnly(_db.categories)
        ..addColumns([_db.categories.id])
        ..where(_db.categories.parentId.isIn(filter.categoryIds));
      query.where(
        (t) =>
            t.categoryId.isIn(filter.categoryIds) |
            t.categoryId.isInQuery(childSub),
      );
    }
    if (filter.types.isNotEmpty) {
      query.where(
        (t) => t.type.isIn(filter.types.map((e) => e.index).toList()),
      );
    }
    if (filter.from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(filter.from!));
    }
    if (filter.to != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(filter.to!));
    }
    if (filter.minMinor != null) {
      query.where((t) => t.amountMinor.isBiggerOrEqualValue(filter.minMinor!));
    }
    if (filter.maxMinor != null) {
      query.where((t) => t.amountMinor.isSmallerOrEqualValue(filter.maxMinor!));
    }
    if (filter.tagIds.isNotEmpty) {
      final tagSub = _db.selectOnly(_db.transactionTags)
        ..addColumns([_db.transactionTags.transactionId])
        ..where(_db.transactionTags.tagId.isIn(filter.tagIds));
      query.where((t) => t.id.isInQuery(tagSub));
    }
    return query.watch();
  }

  /// Distinct payees matching [query] (prefix), ranked by frequency then
  /// recency. Empty query returns the overall most-frequent payees.
  Future<List<String>> payeeSuggestions(String query, {int limit = 5}) async {
    final like = '${query.toLowerCase()}%';
    final rows = await _db
        .customSelect(
          '''
      SELECT payee, COUNT(*) AS cnt, MAX(date) AS last
      FROM transactions
      WHERE deleted_at IS NULL AND payee IS NOT NULL AND payee != ''
        AND LOWER(payee) LIKE ?
      GROUP BY payee
      ORDER BY cnt DESC, last DESC
      LIMIT ?
      ''',
          variables: [Variable<String>(like), Variable<int>(limit)],
          readsFrom: {_db.transactions},
        )
        .get();
    return rows.map((r) => r.read<String>('payee')).toList();
  }

  /// The category most often used with [payee], if any.
  Future<int?> commonCategoryForPayee(String payee) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT category_id, COUNT(*) AS cnt
      FROM transactions
      WHERE deleted_at IS NULL AND category_id IS NOT NULL
        AND LOWER(payee) = ?
      GROUP BY category_id
      ORDER BY cnt DESC
      LIMIT 1
      ''',
          variables: [Variable<String>(payee.toLowerCase())],
          readsFrom: {_db.transactions},
        )
        .get();
    if (rows.isEmpty) return null;
    return rows.first.read<int?>('category_id');
  }

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

  /// Bulk re-categorize (multi-select action).
  Future<void> setCategory(int id, int categoryId) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        categoryId: Value(categoryId),
        updatedAt: Value(DateTime.now()),
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
      recurringRuleId: Value(d.recurringRuleId),
      debtId: Value(d.debtId),
      updatedAt: touch ? Value(DateTime.now()) : const Value.absent(),
    );
  }
}
