import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/accounts/presentation/account_detail_screen.dart';
import 'package:ledgr/features/accounts/presentation/accounts_screen.dart';
import 'package:ledgr/features/home/presentation/home_screen.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ledgr/features/transactions/presentation/transactions_screen.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

class _Seed {
  const _Seed(this.db, this.cash, this.bank);
  final AppDatabase db;
  final int cash;
  final int bank;
}

Future<_Seed> _seed() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final accounts = AccountRepository(db);
  final tx = TransactionRepository(db);
  final cash = await accounts.create(
    name: 'Cash',
    type: AccountType.cash,
    icon: 'payments',
    color: 0xFF00696D,
    currency: 'PKR',
    openingBalanceMinor: 500000,
  );
  final bank = await accounts.create(
    name: 'Bank',
    type: AccountType.bank,
    icon: 'account_balance',
    color: 0xFF1565C0,
    currency: 'PKR',
  );
  final now = DateTime.now();
  await tx.create(
    TransactionDraft(
      type: TxType.expense,
      amountMinor: 15000,
      currency: 'PKR',
      accountId: cash,
      categoryId: 1,
      date: now,
      payee: 'Cafe',
    ),
  );
  await tx.create(
    TransactionDraft(
      type: TxType.income,
      amountMinor: 300000,
      currency: 'PKR',
      accountId: bank,
      categoryId: 19,
      date: now,
    ),
  );
  await tx.create(
    TransactionDraft(
      type: TxType.transfer,
      amountMinor: 20000,
      currency: 'PKR',
      accountId: cash,
      toAccountId: bank,
      date: now,
    ),
  );
  return _Seed(db, cash, bank);
}

Widget _wrap(AppDatabase db, Widget screen) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
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

void main() {
  testWidgets('accounts screen shows net worth and grouped accounts', (
    tester,
  ) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(_wrap(seed.db, const AccountsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Net worth'), findsOneWidget);
    // 'Cash'/'Bank' appear both as a group header and an account name.
    expect(find.text('Cash'), findsWidgets);
    expect(find.text('Bank'), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('accounts FAB opens the create form', (tester) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(_wrap(seed.db, const AccountsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Savings');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final rows = await seed.db.select(seed.db.accounts).get();
    expect(rows.any((a) => a.name == 'Savings'), isTrue);

    await _teardown(tester);
  });

  testWidgets('home dashboard renders net worth and recent activity', (
    tester,
  ) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(_wrap(seed.db, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Cafe'), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('transactions screen groups by day with a month summary', (
    tester,
  ) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(_wrap(seed.db, const TransactionsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Net'), findsOneWidget);
    expect(find.text('Cafe'), findsWidgets);

    // Move to the previous month → empty state.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Nothing this month'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('tapping a transaction opens the detail sheet and duplicates', (
    tester,
  ) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(_wrap(seed.db, const TransactionsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cafe').first);
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);

    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    final expenses = await (seed.db.select(
      seed.db.transactions,
    )..where((t) => t.type.equalsValue(TxType.expense))).get();
    expect(expenses.length, 2); // original + duplicate

    await _teardown(tester);
  });

  testWidgets('account detail shows balance and history', (tester) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(
      _wrap(seed.db, AccountDetailScreen(accountId: seed.cash)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Cafe'), findsWidgets);

    // Reconcile flow.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconcile'));
    await tester.pumpAndSettle();
    expect(find.text('Create adjustment'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('add income with a category saves', (tester) async {
    final seed = await _seed();
    addTearDown(seed.db.close);

    await tester.pumpWidget(_wrap(seed.db, const AddTransactionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    for (final digit in ['5', '0', '0']) {
      await tester.tap(find.widgetWithText(Material, digit).first);
      await tester.pump();
    }

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final income = await (seed.db.select(
      seed.db.transactions,
    )..where((t) => t.type.equalsValue(TxType.income))).get();
    expect(income.length, 2); // seeded + new
    await _teardown(tester);
  });
}
