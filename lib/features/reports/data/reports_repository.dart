import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/reports/domain/report_models.dart';

/// Read-only aggregate queries for the reports and dashboard.
class ReportsRepository {
  ReportsRepository(this._db, this._resolver);

  final AppDatabase _db;
  final PeriodResolver _resolver;

  /// Re-runs [query] whenever money-affecting tables change, so dashboard
  /// and report aggregates stay live (PLAN.md: DB is the source of truth).
  Stream<T> _watch<T>(Future<T> Function() query) async* {
    yield await query();
    yield* _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.transactions,
            _db.accounts,
            _db.categories,
          ]),
        )
        .asyncMap((_) => query());
  }

  Stream<List<CategorySpend>> watchSpendByCategory(Period period) =>
      _watch(() => spendByCategory(period));

  Stream<MonthPoint> watchMonthTotals(Period period) =>
      _watch(() => monthTotals(period));

  Stream<List<PayeeTotal>> watchTopPayees(Period period) =>
      _watch(() => topPayees(period));

  Stream<List<MonthPoint>> watchMonthlyTrend(Period period) =>
      _watch(() => monthlyTrend(period));

  Stream<List<NetWorthPoint>> watchNetWorthSeries(Period period) =>
      _watch(() => netWorthSeries(period));

  /// Expense totals per **top-level** category in [period]; subcategory spend
  /// rolls up to its parent. Descending by amount.
  Future<List<CategorySpend>> spendByCategory(Period period) async {
    final amount = _db.transactions.amountMinor.sum();
    final catId = _db.transactions.categoryId;
    final rows =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([catId, amount])
              ..where(_expenseIn(period))
              ..groupBy([catId]))
            .get();

    // Map child -> parent for roll-up.
    final categories = await _db.select(_db.categories).get();
    final parentOf = {for (final c in categories) c.id: c.parentId};

    final totals = <int, int>{};
    for (final r in rows) {
      // Uncategorized spending gets its own bucket (id -1) so the
      // breakdown always sums to what was actually spent.
      final id = r.read(catId) ?? CategorySpend.uncategorizedId;
      final top = parentOf[id] ?? id;
      totals[top] = (totals[top] ?? 0) + (r.read(amount) ?? 0);
    }
    final result =
        totals.entries
            .map((e) => CategorySpend(categoryId: e.key, totalMinor: e.value))
            .toList()
          ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return result;
  }

  Stream<List<CategorySpend>> watchSpendByChildren(
    int parentId,
    Period period,
  ) => _watch(() => spendByChildren(parentId, period));

  /// Expense totals inside one parent category in [period]: one row per
  /// subcategory, plus a row keyed by [parentId] itself for spend logged
  /// directly on the parent. Descending by amount; zero-spend children are
  /// omitted.
  Future<List<CategorySpend>> spendByChildren(
    int parentId,
    Period period,
  ) async {
    final children = await (_db.select(
      _db.categories,
    )..where((c) => c.parentId.equals(parentId) & c.deletedAt.isNull())).get();
    final ids = {parentId, ...children.map((c) => c.id)};

    final amount = _db.transactions.amountMinor.sum();
    final catId = _db.transactions.categoryId;
    final rows =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([catId, amount])
              ..where(_expenseIn(period) & catId.isIn(ids))
              ..groupBy([catId]))
            .get();

    final result = [
      for (final r in rows)
        CategorySpend(
          categoryId: r.read(catId)!,
          totalMinor: r.read(amount) ?? 0,
        ),
    ]..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return result;
  }

  /// Income and expense totals for [period] (transfers/adjustments excluded).
  Future<MonthPoint> monthTotals(Period period) async {
    return MonthPoint(
      year: period.anchorYear,
      month: period.anchorMonth,
      incomeMinor: await _sumOfType(period, TxType.income),
      expenseMinor: await _sumOfType(period, TxType.expense),
    );
  }

  Future<int> _sumOfType(Period period, TxType type) async {
    final amount = _db.transactions.amountMinor.sum();
    final row =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([amount])
              ..where(
                _db.transactions.deletedAt.isNull() &
                    _db.transactions.type.equalsValue(type) &
                    _db.transactions.date.isBiggerOrEqualValue(period.start) &
                    _db.transactions.date.isSmallerThanValue(period.end),
              ))
            .getSingle();
    return row.read(amount) ?? 0;
  }

  /// Top expense payees in [period], descending.
  Future<List<PayeeTotal>> topPayees(Period period, {int limit = 5}) async {
    final amount = _db.transactions.amountMinor.sum();
    final payee = _db.transactions.payee;
    final rows =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([payee, amount])
              ..where(_expenseIn(period) & payee.isNotNull())
              ..groupBy([payee])
              ..orderBy([OrderingTerm.desc(amount)])
              ..limit(limit))
            .get();
    return [
      for (final r in rows)
        PayeeTotal(payee: r.read(payee)!, totalMinor: r.read(amount) ?? 0),
    ];
  }

  /// Income/expense for the [count] periods ending at [current], oldest first.
  Future<List<MonthPoint>> monthlyTrend(
    Period current, {
    int count = 12,
  }) async {
    final periods = <Period>[];
    var p = current;
    for (var i = 0; i < count; i++) {
      periods.add(p);
      p = _resolver.previous(p);
    }
    final points = <MonthPoint>[];
    for (final period in periods.reversed) {
      points.add(await monthTotals(period));
    }
    return points;
  }

  /// Net worth as of end-of-day [date]: opening balances plus the signed effect
  /// of every non-deleted transaction dated on or before [date], counting only
  /// accounts flagged include-in-net-worth.
  Future<int> netWorthAsOf(DateTime date) async {
    final accounts =
        await (_db.select(_db.accounts)..where(
              (a) => a.includeInNetWorth.equals(true) & a.deletedAt.isNull(),
            ))
            .get();
    final ids = accounts.map((a) => a.id).toSet();
    var total = accounts.fold(0, (s, a) => s + a.openingBalanceMinor);

    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final txs =
        await (_db.select(_db.transactions)..where(
              (t) => t.deletedAt.isNull() & t.date.isSmallerOrEqualValue(end),
            ))
            .get();
    for (final t in txs) {
      if (ids.contains(t.accountId)) total += t.signedMinorFor(t.accountId);
      if (t.toAccountId != null && ids.contains(t.toAccountId)) {
        total += t.signedMinorFor(t.toAccountId!);
      }
    }
    return total;
  }

  /// Net worth at the end of each of the [count] periods ending at [current].
  Future<List<NetWorthPoint>> netWorthSeries(
    Period current, {
    int count = 12,
  }) async {
    final periods = <Period>[];
    var p = current;
    for (var i = 0; i < count; i++) {
      periods.add(p);
      p = _resolver.previous(p);
    }
    final points = <NetWorthPoint>[];
    for (final period in periods.reversed) {
      final asOf = period.end.subtract(const Duration(days: 1));
      points.add(NetWorthPoint(date: asOf, minor: await netWorthAsOf(asOf)));
    }
    return points;
  }

  Expression<bool> _expenseIn(Period period) =>
      _db.transactions.deletedAt.isNull() &
      _db.transactions.type.equalsValue(TxType.expense) &
      _db.transactions.date.isBiggerOrEqualValue(period.start) &
      _db.transactions.date.isSmallerThanValue(period.end);
}
