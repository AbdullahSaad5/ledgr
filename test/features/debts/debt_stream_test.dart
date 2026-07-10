import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';

void main() {
  test('debts stream re-emits on create, payment, edit, delete', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DebtRepository(db, TransactionRepository(db));

    final emissions = <List<DebtWithRemaining>>[];
    final sub = repo.watchByDirection(DebtDirection.lent).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final id = await repo.create(
      person: 'Ali',
      direction: DebtDirection.lent,
      principalMinor: 5000,
      currency: 'PKR',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final afterCreate = emissions.length;

    final d = (await repo.watchByDirection(DebtDirection.lent).first).single;
    await repo.addPayment(d, amountMinor: 1000);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final afterPayment = emissions.length;

    await repo.update(id, person: 'Ali Khan');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final afterEdit = emissions.length;

    await repo.delete(id);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await sub.cancel();
    expect(afterCreate, greaterThan(1));
    expect(afterPayment, greaterThan(afterCreate));
    expect(afterEdit, greaterThan(afterPayment));
    expect(emissions.length, greaterThan(afterEdit));
    expect(emissions.last, isEmpty);
  });

  test(
    'debts stream stays live when a budgets watcher registered first '
    '(drift stream-cache collision regression, #17)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final budgets = BudgetRepository(db, PeriodResolver(1));
      final debts = DebtRepository(db, TransactionRepository(db));
      final july = PeriodResolver(1).ofAnchor(2026, 7);

      // The home screen does exactly this before the debts screen exists.
      final budgetSub = budgets.watchProgress(july).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final emissions = <List<DebtWithRemaining>>[];
      final debtSub = debts
          .watchByDirection(DebtDirection.lent)
          .listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await debts.create(
        person: 'Bilal',
        direction: DebtDirection.lent,
        principalMinor: 900,
        currency: 'PKR',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await budgetSub.cancel();
      await debtSub.cancel();

      expect(
        emissions.last.map((d) => d.debt.person),
        contains('Bilal'),
        reason: 'debt list must update while a budget watcher is alive',
      );
    },
  );
}
