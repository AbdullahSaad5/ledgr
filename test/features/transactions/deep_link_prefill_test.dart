import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/app/router.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/transactions/presentation/add_transaction_screen.dart';

void main() {
  testWidgets(
      'Tokri deep link prefills amount, payee, and note; user still saves',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: AddTransactionScreen(
            // 45000 hundredths = Rs 450 (the link speaks hundredths;
            // PKR stores 0-decimal minor units).
            prefill: TxPrefill(
              amountHundredths: 45000,
              payee: 'Groceries',
              note: 'Trip from Tokri',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing saved yet — prefill never auto-posts.
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).get();
    expect(saved, hasLength(1));
    expect(saved.single.amountMinor, 450, reason: 'PKR 0dp: Rs 450');
    expect(saved.single.type, TxType.expense);
    expect(saved.single.payee, 'Groceries');
    expect(saved.single.note, 'Trip from Tokri');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
