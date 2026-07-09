import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late AccountRepository accounts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TransactionRepository(db);
    accounts = AccountRepository(db);
  });
  tearDown(() => db.close());

  Future<int> account(String name) => accounts.create(
        name: name,
        type: AccountType.bank,
        icon: 'account_balance',
        color: 0xFF000000,
        currency: 'PKR',
      );

  TransactionDraft expense(int acc, int amount, {DateTime? date}) =>
      TransactionDraft(
        type: TxType.expense,
        amountMinor: amount,
        currency: 'PKR',
        accountId: acc,
        categoryId: 1,
        date: date ?? DateTime(2026, 7, 10),
      );

  group('create + validation', () {
    test('creates an expense', () async {
      final acc = await account('A');
      final id = await repo.create(expense(acc, 5000));
      final tx = await repo.watchById(id).first;
      expect(tx.amountMinor, 5000);
      expect(tx.type, TxType.expense);
    });

    test('rejects a transfer without a destination', () async {
      final acc = await account('A');
      expect(
        () => repo.create(
          TransactionDraft(
            type: TxType.transfer,
            amountMinor: 5000,
            currency: 'PKR',
            accountId: acc,
            date: DateTime(2026, 7, 10),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a transfer to the same account', () async {
      final acc = await account('A');
      expect(
        () => repo.create(
          TransactionDraft(
            type: TxType.transfer,
            amountMinor: 5000,
            currency: 'PKR',
            accountId: acc,
            toAccountId: acc,
            date: DateTime(2026, 7, 10),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive amount', () async {
      final acc = await account('A');
      expect(() => repo.create(expense(acc, 0)), throwsArgumentError);
    });
  });

  group('watchInPeriod', () {
    test('includes only transactions inside the half-open range', () async {
      final acc = await account('A');
      await repo.create(expense(acc, 100, date: DateTime(2026, 6, 30)));
      await repo.create(expense(acc, 200, date: DateTime(2026, 7, 15)));
      await repo.create(expense(acc, 300, date: DateTime(2026, 8, 1)));

      final july = PeriodResolver(1).ofAnchor(2026, 7);
      final rows = await repo.watchInPeriod(july).first;
      expect(rows.map((t) => t.amountMinor), [200]);
    });
  });

  group('soft delete + restore (undo)', () {
    test('tombstoned rows leave the period view and come back on restore',
        () async {
      final acc = await account('A');
      final id = await repo.create(expense(acc, 500));
      final july = PeriodResolver(1).ofAnchor(2026, 7);

      expect((await repo.watchInPeriod(july).first).length, 1);
      await repo.softDelete(id);
      expect((await repo.watchInPeriod(july).first).length, 0);
      await repo.restore(id);
      expect((await repo.watchInPeriod(july).first).length, 1);
    });
  });

  group('duplicate', () {
    test('copies fields with a fresh date', () async {
      final acc = await account('A');
      final id = await repo.create(expense(acc, 750));
      final copyId = await repo.duplicate(id);
      expect(copyId, isNot(id));
      final copy = await repo.watchById(copyId).first;
      expect(copy.amountMinor, 750);
      expect(copy.accountId, acc);
    });
  });

  group('transfer affects both balances', () {
    test('source loses amount+fee, target gains amount', () async {
      final a = await account('A');
      final b = await account('B');
      await repo.create(
        TransactionDraft(
          type: TxType.transfer,
          amountMinor: 50000,
          currency: 'PKR',
          accountId: a,
          toAccountId: b,
          feeMinor: 500,
          date: DateTime(2026, 7, 10),
        ),
      );
      expect(await accounts.balance(a), -50500);
      expect(await accounts.balance(b), 50000);
    });
  });
}
