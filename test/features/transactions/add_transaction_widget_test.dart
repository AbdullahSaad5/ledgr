import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/transactions/presentation/add_transaction_screen.dart';

void main() {
  testWidgets('enter an amount on the keypad and save creates a transaction', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed an account so the screen has a source.
    final accountId = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddTransactionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Type 1200 on the keypad.
    for (final digit in ['1', '2', '0', '0']) {
      await tester.tap(find.widgetWithText(Material, digit).first);
      await tester.pump();
    }

    // Save.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).get();
    expect(saved, hasLength(1));
    expect(saved.single.amountMinor, 120000); // 1200.00 in minor units
    expect(saved.single.accountId, accountId);
    expect(saved.single.type, TxType.expense);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
