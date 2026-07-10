import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('schema + seed', () {
    test('schema version is 4 (Bills subcategories)', () {
      expect(db.schemaVersion, 4);
    });

    test('seeds default categories (18+5 expense + 7 income)', () async {
      final all = await db.select(db.categories).get();
      expect(all.where((c) => c.kind == CategoryKind.expense).length, 23);
      expect(all.where((c) => c.kind == CategoryKind.income).length, 7);
      expect(all.every((c) => c.isDefault), isTrue);
    });

    test('seeds utility subcategories under Bills & Utilities (#16)', () async {
      final all = await db.select(db.categories).get();
      final bills = all.firstWhere((c) => c.name == 'Bills & Utilities');
      final children = all.where((c) => c.parentId == bills.id).toList();
      expect(children.map((c) => c.name).toSet(), {
        'Electricity',
        'Gas',
        'Water',
        'Internet',
        'Mobile',
      });
      expect(
        children.every((c) => c.kind == CategoryKind.expense && c.isDefault),
        isTrue,
      );
      // One level only: no other seeded category has a parent.
      final others = all.where(
        (c) => c.parentId != null && c.parentId != bills.id,
      );
      expect(others, isEmpty);
    });

    test('sync columns are populated on insert', () async {
      final id = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: 'Cash',
              type: AccountType.cash,
              icon: 'payments',
              color: 0xFF000000,
              currency: 'PKR',
              position: 0,
            ),
          );
      final account = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(id))).getSingle();
      expect(account.uuid, isNotEmpty);
      expect(account.deletedAt, isNull);
      expect(account.includeInNetWorth, isTrue);
    });
  });

  group('balanceMinor (ADR-0003 derived balance)', () {
    Future<int> newAccount(String name, {int opening = 0}) {
      return db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: name,
              type: AccountType.bank,
              icon: 'account_balance',
              color: 0xFF000000,
              currency: 'PKR',
              position: 0,
              openingBalanceMinor: Value(opening),
            ),
          );
    }

    Future<void> tx({
      required TxType type,
      required int amount,
      required int account,
      int? toAccount,
      int? fee,
    }) async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              type: type,
              amountMinor: amount,
              currency: 'PKR',
              accountId: account,
              date: DateTime(2026, 7, 1),
              toAccountId: Value(toAccount),
              feeMinor: Value(fee),
            ),
          );
    }

    test('opening balance with no transactions', () async {
      final acc = await newAccount('A', opening: 500000);
      expect(await db.balanceMinor(acc), 500000);
    });

    test('income adds, expense subtracts', () async {
      final acc = await newAccount('A', opening: 100000);
      await tx(type: TxType.income, amount: 50000, account: acc);
      await tx(type: TxType.expense, amount: 30000, account: acc);
      expect(await db.balanceMinor(acc), 120000);
    });

    test('transfer moves money between accounts, fee hits source', () async {
      final a = await newAccount('A', opening: 200000);
      final b = await newAccount('B');
      await tx(
        type: TxType.transfer,
        amount: 50000,
        account: a,
        toAccount: b,
        fee: 1000,
      );
      expect(await db.balanceMinor(a), 200000 - 50000 - 1000);
      expect(await db.balanceMinor(b), 50000);
    });

    test('soft-deleted transactions are excluded', () async {
      final acc = await newAccount('A', opening: 100000);
      await tx(type: TxType.expense, amount: 40000, account: acc);
      await (db.update(db.transactions)..where((t) => t.accountId.equals(acc)))
          .write(TransactionsCompanion(deletedAt: Value(DateTime(2026, 7, 2))));
      expect(await db.balanceMinor(acc), 100000);
    });
  });
}
