import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/backup/data/csv_importer.dart';

void main() {
  group('CsvImporter.parseRows (pure)', () {
    test('splits simple rows and skips the header', () {
      final rows = CsvImporter.parseRows(
        'Date,Type,Amount,Account,Category,Payee,Note\n'
        '2026-07-01,expense,Rs 500,Cash,Groceries,Imtiaz,weekly\n',
      );
      expect(rows, hasLength(1));
      expect(rows.first, [
        '2026-07-01',
        'expense',
        'Rs 500',
        'Cash',
        'Groceries',
        'Imtiaz',
        'weekly',
      ]);
    });

    test('handles quoted fields with commas and escaped quotes', () {
      final rows = CsvImporter.parseRows(
        'Date,Type,Amount,Account,Category,Payee,Note\n'
        // CSV fields are comma-joined, so the split point has no space.
        // ignore: missing_whitespace_between_adjacent_strings
        '2026-07-01,expense,"Rs 1,500",Cash,Bills,'
        '"Karachi ""K"" Store","a, note"\n',
      );
      expect(rows.first[2], 'Rs 1,500');
      expect(rows.first[5], 'Karachi "K" Store');
      expect(rows.first[6], 'a, note');
    });

    test('parseAmount strips symbols and grouping per currency', () {
      expect(CsvImporter.parseAmountMinor('Rs 2,300', 'PKR'), 2300);
      expect(CsvImporter.parseAmountMinor(r'$3,240.00', 'USD'), 324000);
      expect(CsvImporter.parseAmountMinor('-Rs 500', 'PKR'), -500);
    });
  });

  group('CsvImporter.import (db)', () {
    late AppDatabase db;
    late CsvImporter importer;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      importer = CsvImporter(db);
      await AccountRepository(db).create(
        name: 'Cash',
        type: AccountType.cash,
        icon: 'payments',
        color: 0xFF000000,
        currency: 'PKR',
      );
    });
    tearDown(() => db.close());

    const header = 'Date,Type,Amount,Account,Category,Payee,Note\n';

    test('imports rows, reusing accounts and categories by name', () async {
      final summary = await importer.import(
        '${header}2026-07-01,expense,Rs 500,Cash,Groceries,Imtiaz,\n'
        '2026-07-02,income,Rs 9000,Cash,Salary,,\n',
        currency: 'PKR',
      );
      expect(summary.imported, 2);
      expect(summary.skipped, 0);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      final expense = txs.firstWhere((t) => t.type == TxType.expense);
      expect(expense.amountMinor, 500);
      expect(expense.payee, 'Imtiaz');
      // Seeded 'Groceries' was reused, not duplicated.
      final categories = await db.select(db.categories).get();
      expect(categories.where((c) => c.name == 'Groceries'), hasLength(1));
    });

    test('creates missing accounts and categories', () async {
      await importer.import(
        '${header}2026-07-01,expense,Rs 700,Meezan Bank,Chai,,\n',
        currency: 'PKR',
      );
      final accounts = await db.select(db.accounts).get();
      expect(accounts.map((a) => a.name), contains('Meezan Bank'));
      final categories = await db.select(db.categories).get();
      final chai = categories.firstWhere((c) => c.name == 'Chai');
      expect(chai.kind, CategoryKind.expense);
    });

    test('maps "Parent > Child" category paths onto subcategories', () async {
      await importer.import(
        // CSV fields are comma-joined, so the split point has no space.
        // ignore: missing_whitespace_between_adjacent_strings
        '${header}2026-07-01,expense,Rs 900,'
        'Cash,Bills & Utilities > Electricity,,\n',
        currency: 'PKR',
      );
      final txs = await db.select(db.transactions).get();
      final categories = await db.select(db.categories).get();
      final electricity = categories.firstWhere((c) => c.name == 'Electricity');
      expect(txs.single.categoryId, electricity.id);
      expect(electricity.parentId, isNotNull);
    });

    test('skips exact duplicates and unsupported transfer rows', () async {
      const row = '2026-07-01,expense,Rs 500,Cash,Groceries,Imtiaz,\n';
      await importer.import(header + row, currency: 'PKR');
      final again = await importer.import(
        '$header$row'
        '2026-07-03,transfer,Rs 100,Cash,,,\n',
        currency: 'PKR',
      );
      expect(again.imported, 0);
      expect(again.skipped, 2); // 1 duplicate + 1 transfer
      expect(await db.select(db.transactions).get(), hasLength(1));
    });
  });
}
