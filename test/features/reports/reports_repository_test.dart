import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/categories/data/category_repository.dart';
import 'package:ledgr/features/reports/data/reports_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  late AppDatabase db;
  late ReportsRepository reports;
  late TransactionRepository tx;
  late int cash;
  final resolver = PeriodResolver(1);
  final july = PeriodResolver(1).ofAnchor(2026, 7);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reports = ReportsRepository(db, resolver);
    tx = TransactionRepository(db);
    cash = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
      openingBalanceMinor: 100000,
    );
  });
  tearDown(() => db.close());

  Future<void> expense(
    int amount,
    int category, {
    String? payee,
    DateTime? d,
  }) => tx.create(
    TransactionDraft(
      type: TxType.expense,
      amountMinor: amount,
      currency: 'PKR',
      accountId: cash,
      categoryId: category,
      date: d ?? DateTime(2026, 7, 10),
      payee: payee,
    ),
  );

  test('spendByCategory rolls subcategories into their parent', () async {
    final categories = CategoryRepository(db);
    final bills = await categories.create(
      name: 'Bills',
      kind: CategoryKind.expense,
      icon: 'receipt_long',
      color: 0xFF000000,
    );
    final electricity = await categories.create(
      name: 'Electricity',
      kind: CategoryKind.expense,
      icon: 'bolt',
      color: 0xFF000000,
      parentId: bills,
    );
    await expense(3000, bills);
    await expense(5000, electricity); // rolls into Bills
    await expense(2000, 1); // Food & Dining (seeded)

    final spend = await reports.spendByCategory(july);
    final billsRow = spend.firstWhere((s) => s.categoryId == bills);
    expect(billsRow.totalMinor, 8000);
    // Sorted descending: Bills (8000) before Food (2000).
    expect(spend.first.categoryId, bills);
  });

  test('monthTotals sums income and expense, ignoring other months', () async {
    await tx.create(
      TransactionDraft(
        type: TxType.income,
        amountMinor: 300000,
        currency: 'PKR',
        accountId: cash,
        categoryId: 19,
        date: DateTime(2026, 7, 5),
      ),
    );
    await expense(50000, 1);
    await expense(999, 1, d: DateTime(2026, 6, 30)); // previous month

    final totals = await reports.monthTotals(july);
    expect(totals.incomeMinor, 300000);
    expect(totals.expenseMinor, 50000);
    expect(totals.netMinor, 250000);
  });

  test('topPayees ranks expense payees', () async {
    await expense(1000, 1, payee: 'Careem');
    await expense(4000, 1, payee: 'Careem');
    await expense(2000, 1, payee: 'Daraz');
    final top = await reports.topPayees(july);
    expect(top.first.payee, 'Careem');
    expect(top.first.totalMinor, 5000);
    expect(top[1].payee, 'Daraz');
  });

  test('monthlyTrend returns oldest-first points', () async {
    await expense(50000, 1); // July
    final trend = await reports.monthlyTrend(july, count: 3);
    expect(trend.length, 3);
    expect(trend.last.month, 7); // current period last
    expect(trend.last.expenseMinor, 50000);
    expect(trend.first.month, 5);
  });

  test('netWorthAsOf includes only transactions up to the date', () async {
    await expense(10000, 1, d: DateTime(2026, 7, 5));
    await expense(20000, 1, d: DateTime(2026, 7, 25));

    // As of Jul 10: opening 100000 - 10000 = 90000.
    expect(await reports.netWorthAsOf(DateTime(2026, 7, 10)), 90000);
    // As of Jul 31: 100000 - 30000 = 70000.
    expect(await reports.netWorthAsOf(DateTime(2026, 7, 31)), 70000);
  });

  test('netWorthSeries produces one point per period', () async {
    await expense(10000, 1);
    final series = await reports.netWorthSeries(july, count: 3);
    expect(series.length, 3);
    expect(series.last.minor, 90000); // end of July
  });
}
