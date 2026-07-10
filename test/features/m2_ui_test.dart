import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/categories/presentation/categories_screen.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';
import 'package:ledgr/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ledgr/features/transactions/presentation/search_screen.dart';
import 'package:ledgr/features/transactions/presentation/transactions_screen.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _wrap(AppDatabase db, Widget screen, {List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db), ...extra],
    child: MaterialApp(
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: screen,
    ),
  );
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

Future<({int cash, int bank})> _seedAccountsAndTx(AppDatabase db) async {
  final accounts = AccountRepository(db);
  final tx = TransactionRepository(db);
  final cash = await accounts.create(
    name: 'Cash',
    type: AccountType.cash,
    icon: 'payments',
    color: 0xFF000000,
    currency: 'PKR',
    openingBalanceMinor: 500000,
  );
  final bank = await accounts.create(
    name: 'Bank',
    type: AccountType.bank,
    icon: 'account_balance',
    color: 0xFF000000,
    currency: 'PKR',
  );
  await tx.create(
    TransactionDraft(
      type: TxType.expense,
      amountMinor: 100,
      currency: 'PKR',
      accountId: cash,
      categoryId: 1,
      date: DateTime.now(),
      payee: 'Cafe',
    ),
  );
  return (cash: cash, bank: bank);
}

void main() {
  testWidgets('category management lists seeded categories and adds one', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const CategoriesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Hobbies');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // New category lands at the end of the list (off-screen), so verify in DB.
    final created = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Hobbies'))).get();
    expect(created, hasLength(1));

    await _teardown(tester);
  });

  testWidgets('search filters by text', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final account = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
    final tx = TransactionRepository(db);
    await tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: 100,
        currency: 'PKR',
        accountId: account,
        categoryId: 1,
        date: DateTime(2026, 7, 1),
        payee: 'Careem',
      ),
    );
    await tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: 200,
        currency: 'PKR',
        accountId: account,
        categoryId: 1,
        date: DateTime(2026, 7, 1),
        payee: 'Daraz',
      ),
    );

    await tester.pumpWidget(
      _wrap(
        db,
        const SearchScreen(),
        extra: [
          transactionFilterProvider.overrideWith(
            (ref) => const TransactionFilter(text: 'careem'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Careem'), findsOneWidget);
    expect(find.text('Daraz'), findsNothing);
    expect(find.text('1 transactions'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('filter sheet toggles a type and applies', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedAccountsAndTx(db);

    await tester.pumpWidget(_wrap(db, const SearchScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);

    await tester.tap(find.text('Expense').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    // Cafe (an expense) still shows under the type filter.
    expect(find.text('Cafe'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('add a transfer saves a single row touching both accounts', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await _seedAccountsAndTx(db);

    await tester.pumpWidget(_wrap(db, const AddTransactionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    // Pick the destination account.
    await tester.tap(find.text('To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();

    for (final d in ['1', '0', '0', '0']) {
      await tester.tap(find.widgetWithText(Material, d).first);
      await tester.pump();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final transfers = await (db.select(
      db.transactions,
    )..where((t) => t.type.equalsValue(TxType.transfer))).get();
    expect(transfers, hasLength(1));
    expect(transfers.single.accountId, ids.cash);
    expect(transfers.single.toAccountId, ids.bank);

    await _teardown(tester);
  });

  testWidgets(
    'category picker shows seeded categories on first open (regression)',
    (tester) async {
      // Regression: the sheet used a one-shot ref.read of an unprimed
      // StreamProvider, so the very first open rendered an empty grid.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedAccountsAndTx(db);

      await tester.pumpWidget(_wrap(db, const AddTransactionScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();

      // Seeded expense categories render in the sheet.
      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      // Selection lands on the tile.
      expect(find.text('Groceries'), findsOneWidget);

      await _teardown(tester);
    },
  );

  testWidgets('long-press selects and the selection bar deletes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedAccountsAndTx(db);

    await tester.pumpWidget(_wrap(db, const TransactionsScreen()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Cafe'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    final live = await (db.select(
      db.transactions,
    )..where((t) => t.deletedAt.isNull())).get();
    expect(live, isEmpty);

    await _teardown(tester);
  });

  testWidgets('deleting an unused category removes it', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const CategoriesScreen()));
    await tester.pumpAndSettle();

    // First category's overflow menu → Delete (no transactions use it).
    await tester.tap(find.byIcon(LucideIcons.moreVertical).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final active =
        await (db.select(db.categories)
              ..where((c) => c.kind.equalsValue(CategoryKind.expense))
              ..where((c) => c.deletedAt.isNull()))
            .get();
    expect(active, hasLength(22)); // 18+5 seeded − 1 deleted

    await _teardown(tester);
  });
}
