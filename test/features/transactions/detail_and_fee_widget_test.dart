import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/tags/data/tag_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';

void main() {
  late AppDatabase db;
  late int cash;
  late int bank;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = AccountRepository(db);
    cash = await accounts.create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
    bank = await accounts.create(
      name: 'Bank',
      type: AccountType.bank,
      icon: 'account_balance',
      color: 0xFF000000,
      currency: 'PKR',
    );
  });
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: child),
  );

  testWidgets('detail sheet shows tags row and receipts section', (
    tester,
  ) async {
    final tx = TransactionRepository(db);
    final tags = TagRepository(db);
    final id = await tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: 700,
        currency: 'PKR',
        accountId: cash,
        categoryId: 1,
        date: DateTime(2026, 7, 10),
        payee: 'Chai Wala',
        note: 'evening chai',
      ),
    );
    final work = await tags.getOrCreate('work');
    final tea = await tags.getOrCreate('tea');
    await tags.setTagsForTransaction(id, {work.id, tea.id});

    await tester.pumpWidget(
      wrap(Scaffold(body: TransactionDetailSheet(transactionId: id))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chai Wala'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.textContaining('work'), findsOneWidget);
    expect(find.textContaining('tea'), findsOneWidget);
    expect(find.text('Receipts'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('transfer fee pill stores a fee on the saved transfer', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AddTransactionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    // Fee pill only exists for transfers.
    expect(find.text('Fee'), findsWidgets);
    await tester.tap(find.text('Fee').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '50');
    await tester.tap(find.text('Save fee'));
    await tester.pumpAndSettle();
    expect(find.text('Fee added'), findsOneWidget);

    // 300 from cash to bank.
    for (final digit in ['3', '0', '0']) {
      await tester.tap(find.widgetWithText(Material, digit).first);
      await tester.pump();
    }
    // Pick the destination account.
    await tester.tap(find.text('Choose').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).get();
    expect(saved.single.type, TxType.transfer);
    expect(saved.single.toAccountId, bank);
    expect(saved.single.feeMinor, 50);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
