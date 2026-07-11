import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/budgets/domain/budget_threshold.dart';
import 'package:ledgr/features/categories/data/category_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  group('crossedThreshold (pure)', () {
    test('detects crossing 80%', () {
      expect(
        crossedThreshold(beforeMinor: 700, afterMinor: 850, limitMinor: 1000),
        BudgetThreshold.eighty,
      );
    });

    test('detects crossing 100%', () {
      expect(
        crossedThreshold(beforeMinor: 900, afterMinor: 1100, limitMinor: 1000),
        BudgetThreshold.hundred,
      );
    });

    test('reports the higher threshold when both cross at once', () {
      expect(
        crossedThreshold(beforeMinor: 0, afterMinor: 1000, limitMinor: 1000),
        BudgetThreshold.hundred,
      );
    });

    test('no crossing when already past the threshold', () {
      expect(
        crossedThreshold(beforeMinor: 850, afterMinor: 900, limitMinor: 1000),
        BudgetThreshold.none,
      );
    });

    test('non-positive limit never triggers', () {
      expect(
        crossedThreshold(beforeMinor: 0, afterMinor: 100, limitMinor: 0),
        BudgetThreshold.none,
      );
    });
  });

  group('BudgetRepository', () {
    late AppDatabase db;
    late BudgetRepository repo;
    late TransactionRepository tx;
    late int cash;
    final july = PeriodResolver(1).ofAnchor(2026, 7);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BudgetRepository(db, PeriodResolver(1));
      tx = TransactionRepository(db);
      cash = await AccountRepository(db).create(
        name: 'Cash',
        type: AccountType.cash,
        icon: 'payments',
        color: 0xFF000000,
        currency: 'PKR',
      );
    });
    tearDown(() => db.close());

    Future<void> expense(int amount, int category) => tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: amount,
        currency: 'PKR',
        accountId: cash,
        categoryId: category,
        date: DateTime(2026, 7, 10),
      ),
    );

    test('overall budget counts all expense', () async {
      final id = await repo.create(limitMinor: 100000);
      await expense(30000, 1);
      await expense(20000, 2);
      final budget = await (db.select(
        db.budgets,
      )..where((b) => b.id.equals(id))).getSingle();
      expect(await repo.spentFor(budget, july), 50000);
    });

    test('category budget includes subcategories', () async {
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
      final id = await repo.create(categoryId: bills, limitMinor: 100000);
      await expense(10000, bills);
      await expense(15000, electricity);
      await expense(99999, 1); // unrelated category
      final budget = await (db.select(
        db.budgets,
      )..where((b) => b.id.equals(id))).getSingle();
      expect(await repo.spentFor(budget, july), 25000);
    });

    test('covers matches own category, its children, and overall', () async {
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
      final billsBudget = await repo.create(
        categoryId: bills,
        limitMinor: 100000,
      );
      final overall = await repo.create(limitMinor: 100000);
      final rows = {
        for (final b in await db.select(db.budgets).get()) b.id: b,
      };

      expect(await repo.covers(rows[billsBudget]!, bills), isTrue);
      expect(await repo.covers(rows[billsBudget]!, electricity), isTrue);
      expect(await repo.covers(rows[billsBudget]!, 1), isFalse);
      expect(await repo.covers(rows[billsBudget]!, null), isFalse);
      expect(await repo.covers(rows[overall]!, electricity), isTrue);
      expect(await repo.covers(rows[overall]!, null), isTrue);
    });

    group('rollover (#17)', () {
      Future<void> expenseOn(int amount, DateTime date) => tx.create(
        TransactionDraft(
          type: TxType.expense,
          amountMinor: amount,
          currency: 'PKR',
          accountId: cash,
          categoryId: 1,
          date: date,
        ),
      );

      Future<Budget> budgetCreatedInJune({required int limit}) async {
        final id = await repo.create(limitMinor: limit, rollover: true);
        // Backdate creation so June is the budget's first period.
        await (db.update(db.budgets)..where((b) => b.id.equals(id))).write(
          BudgetsCompanion(createdAt: Value(DateTime(2026, 6, 5))),
        );
        return (db.select(
          db.budgets,
        )..where((b) => b.id.equals(id))).getSingle();
      }

      test('unspent from previous periods carries forward', () async {
        final budget = await budgetCreatedInJune(limit: 10000);
        await expenseOn(6000, DateTime(2026, 6, 10));
        // June left 4,000 unspent → July's effective limit grows.
        expect(await repo.carryFor(budget, july), 4000);
      });

      test('overspend carries as a negative adjustment', () async {
        final budget = await budgetCreatedInJune(limit: 10000);
        await expenseOn(13000, DateTime(2026, 6, 10));
        expect(await repo.carryFor(budget, july), -3000);
      });

      test('non-rollover budgets never carry', () async {
        final id = await repo.create(limitMinor: 10000);
        await expenseOn(1000, DateTime(2026, 6, 10));
        final budget = await (db.select(
          db.budgets,
        )..where((b) => b.id.equals(id))).getSingle();
        expect(await repo.carryFor(budget, july), 0);
      });

      test('watchProgress exposes carry and effective limit', () async {
        await budgetCreatedInJune(limit: 10000);
        await expenseOn(6000, DateTime(2026, 6, 10));
        await expenseOn(5000, DateTime(2026, 7, 10));

        final progress = (await repo.watchProgress(july).first).single;
        expect(progress.carryMinor, 4000);
        expect(progress.effectiveLimitMinor, 14000);
        expect(progress.spentMinor, 5000);
        expect(progress.remainingMinor, 9000);
        expect(progress.fraction, closeTo(5000 / 14000, 1e-9));
      });
    });

    test(
      'watchProgress reflects spend and updates on new transactions',
      () async {
        await repo.create(limitMinor: 100000);
        final first = await repo.watchProgress(july).first;
        expect(first.single.spentMinor, 0);
        expect(first.single.fraction, 0);

        await expense(80000, 1);
        final next = await repo.watchProgress(july).first;
        expect(next.single.spentMinor, 80000);
        expect(next.single.fraction, closeTo(0.8, 1e-9));
      },
    );
  });
}
