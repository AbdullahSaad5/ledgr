import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/backup/data/backup_service.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

void main() {
  test('export then clear then import restores identical data', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = BackupService(db);

    final accounts = AccountRepository(db);
    final tx = TransactionRepository(db);
    final cash = await accounts.create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF00696D,
      currency: 'PKR',
      openingBalanceMinor: 250000,
    );
    await tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: 15050,
        currency: 'PKR',
        accountId: cash,
        categoryId: 1,
        date: DateTime(2026, 7, 10),
        payee: 'Cafe',
      ),
    );

    final json = await backup.export();

    // Wipe.
    await db.delete(db.transactions).go();
    await db.delete(db.accounts).go();
    await db.delete(db.categories).go();
    expect(await db.select(db.accounts).get(), isEmpty);

    await backup.import(json);

    // Round-trips at millisecond precision, so compare meaningful fields.
    final accs = await db.select(db.accounts).get();
    expect(accs, hasLength(1));
    expect(accs.single.name, 'Cash');
    expect(accs.single.uuid, isNotEmpty);
    expect(accs.single.openingBalanceMinor, 250000);

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amountMinor, 15050);
    expect(txs.single.payee, 'Cafe');

    // Seeded categories (30) restored.
    expect(await db.select(db.categories).get(), hasLength(30));
  });

  test('rejects an unknown version', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      () => BackupService(db).import('{"version": 99, "tables": {}}'),
      throwsA(isA<FormatException>()),
    );
  });
}
