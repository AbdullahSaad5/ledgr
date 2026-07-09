import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late DebtRepository repo;
  late AccountRepository accounts;
  late int cash;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DebtRepository(db, TransactionRepository(db));
    accounts = AccountRepository(db);
    cash = await accounts.create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
      openingBalanceMinor: 1000000,
    );
  });
  tearDown(() => db.close());

  Future<DebtWithRemaining> firstLent() =>
      repo.watchByDirection(DebtDirection.lent).first.then((l) => l.single);

  test('lending posts an expense and tracks remaining', () async {
    await repo.create(
      person: 'Ali',
      direction: DebtDirection.lent,
      principalMinor: 200000,
      currency: 'PKR',
      accountId: cash,
    );
    // Money left the account.
    expect(await accounts.balance(cash), 800000);
    final debt = await firstLent();
    expect(debt.remainingMinor, 200000);
  });

  test('partial repayment reduces remaining and returns money', () async {
    await repo.create(
      person: 'Ali',
      direction: DebtDirection.lent,
      principalMinor: 200000,
      currency: 'PKR',
      accountId: cash,
    );
    var debt = await firstLent();
    await repo.addPayment(debt, amountMinor: 50000, accountId: cash);

    debt = await firstLent();
    expect(debt.paidMinor, 50000);
    expect(debt.remainingMinor, 150000);
    // 800000 (after lending) + 50000 repaid = 850000.
    expect(await accounts.balance(cash), 850000);
  });

  test('full repayment settles the debt', () async {
    await repo.create(
      person: 'Sara',
      direction: DebtDirection.lent,
      principalMinor: 100000,
      currency: 'PKR',
    );
    var debt = await firstLent();
    await repo.addPayment(debt, amountMinor: 100000);
    debt = await firstLent();
    expect(debt.debt.settled, isTrue);
    expect(debt.remainingMinor, 0);
  });

  test('borrowing brings money in', () async {
    await repo.create(
      person: 'Bank',
      direction: DebtDirection.borrowed,
      principalMinor: 500000,
      currency: 'PKR',
      accountId: cash,
    );
    expect(await accounts.balance(cash), 1500000);
    final borrowed = await repo.watchByDirection(DebtDirection.borrowed).first;
    expect(borrowed.single.remainingMinor, 500000);
  });
}
