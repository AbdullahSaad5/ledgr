import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';

/// A budget paired with its spend for the current period.
class BudgetProgress {
  const BudgetProgress({required this.budget, required this.spentMinor});

  final Budget budget;
  final int spentMinor;

  int get limitMinor => budget.limitMinor;
  bool get isOverall => budget.categoryId == null;

  double get fraction =>
      limitMinor <= 0 ? 0 : (spentMinor / limitMinor).clamp(0.0, 1.0);
  int get remainingMinor => limitMinor - spentMinor;
}

/// Budgets and their spend against a reporting period.
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  Stream<List<Budget>> watchActive() {
    return (_db.select(
      _db.budgets,
    )..where((b) => b.active.equals(true) & b.deletedAt.isNull())).watch();
  }

  Future<int> create({required int limitMinor, int? categoryId}) {
    return _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: Value(categoryId),
            limitMinor: limitMinor,
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

  /// Live progress for every active budget in [period]. Recomputes whenever
  /// budgets or transactions change.
  Stream<List<BudgetProgress>> watchProgress(Period period) {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.budgets, _db.transactions})
        .watch()
        .asyncMap((_) async {
          final budgets = await (_db.select(
            _db.budgets,
          )..where((b) => b.active.equals(true) & b.deletedAt.isNull())).get();
          return [
            for (final b in budgets)
              BudgetProgress(budget: b, spentMinor: await spentFor(b, period)),
          ];
        });
  }

  Future<List<int>> _categoryAndChildren(int categoryId) async {
    final children = await (_db.select(
      _db.categories,
    )..where((c) => c.parentId.equals(categoryId))).get();
    return [categoryId, ...children.map((c) => c.id)];
  }
}
