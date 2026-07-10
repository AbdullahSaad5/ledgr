import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';

/// A budget paired with its spend for the current period. For rollover
/// budgets, [carryMinor] is the signed leftover from previous periods and
/// all derived numbers use the effective limit.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spentMinor,
    this.carryMinor = 0,
  });

  final Budget budget;
  final int spentMinor;
  final int carryMinor;

  int get limitMinor => budget.limitMinor;
  int get effectiveLimitMinor => budget.limitMinor + carryMinor;
  bool get isOverall => budget.categoryId == null;

  double get fraction => effectiveLimitMinor <= 0
      ? 1
      : (spentMinor / effectiveLimitMinor).clamp(0.0, 1.0);
  int get remainingMinor => effectiveLimitMinor - spentMinor;
}

/// Budgets and their spend against a reporting period.
class BudgetRepository {
  BudgetRepository(this._db, this._resolver);

  final AppDatabase _db;
  final PeriodResolver _resolver;

  Stream<List<Budget>> watchActive() {
    return (_db.select(
      _db.budgets,
    )..where((b) => b.active.equals(true) & b.deletedAt.isNull())).watch();
  }

  Future<int> create({
    required int limitMinor,
    int? categoryId,
    bool rollover = false,
  }) {
    return _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: Value(categoryId),
            limitMinor: limitMinor,
            rollover: Value(rollover),
          ),
        );
  }

  Future<void> setRollover(int id, {required bool rollover}) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        rollover: Value(rollover),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateLimit(int id, int limitMinor) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        limitMinor: Value(limitMinor),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Expense spent against [budget] within [period]. A category budget includes
  /// spend on that category and its subcategories; an overall budget counts all
  /// expense.
  Future<int> spentFor(Budget budget, Period period) async {
    final amount = _db.transactions.amountMinor.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amount])
      ..where(
        _db.transactions.deletedAt.isNull() &
            _db.transactions.type.equalsValue(TxType.expense) &
            _db.transactions.date.isBiggerOrEqualValue(period.start) &
            _db.transactions.date.isSmallerThanValue(period.end),
      );

    if (budget.categoryId != null) {
      final ids = await _categoryAndChildren(budget.categoryId!);
      query.where(_db.transactions.categoryId.isIn(ids));
    }
    final row = await query.getSingle();
    return row.read(amount) ?? 0;
  }

  /// Signed leftover carried into [current] for a rollover budget: for each
  /// full period between the budget's creation and [current], unspent limit
  /// adds to the carry and overspend subtracts (#17). Non-rollover budgets
  /// always carry zero. Walks at most 24 periods so a stale budget can't
  /// make progress computation unbounded.
  Future<int> carryFor(Budget budget, Period current) async {
    if (!budget.rollover) return 0;
    var period = _resolver.periodContaining(budget.createdAt);
    var carry = 0;
    var guard = 0;
    while (period.start.isBefore(current.start) && guard < 24) {
      carry += budget.limitMinor - await spentFor(budget, period);
      period = _resolver.next(period);
      guard++;
    }
    return carry;
  }

  /// Live progress for every active budget in [period]. Recomputes whenever
  /// budgets or transactions change. Uses tableUpdates rather than a marker
  /// customSelect — see DebtRepository.watchByDirection for why.
  Stream<List<BudgetProgress>> watchProgress(Period period) async* {
    Future<List<BudgetProgress>> query() async {
      final budgets = await (_db.select(
        _db.budgets,
      )..where((b) => b.active.equals(true) & b.deletedAt.isNull())).get();
      return [
        for (final b in budgets)
          BudgetProgress(
            budget: b,
            spentMinor: await spentFor(b, period),
            carryMinor: await carryFor(b, period),
          ),
      ];
    }

    yield await query();
    yield* _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([_db.budgets, _db.transactions]),
        )
        .asyncMap((_) => query());
  }

  Future<List<int>> _categoryAndChildren(int categoryId) async {
    final children = await (_db.select(
      _db.categories,
    )..where((c) => c.parentId.equals(categoryId))).get();
    return [categoryId, ...children.map((c) => c.id)];
  }
}
