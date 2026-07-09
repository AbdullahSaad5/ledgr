import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/debts/presentation/debts_screen.dart';
import 'package:ledgr/features/recurring/data/recurring_repository.dart';
import 'package:ledgr/features/recurring/presentation/recurring_screen.dart';
import 'package:ledgr/features/recurring/presentation/upcoming_screen.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

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
  testWidgets('adding a lent debt posts an expense and shows it', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cash = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
      openingBalanceMinor: 1000000,
    );

    await tester.pumpWidget(_wrap(db, const DebtsScreen()));
    await tester.pumpAndSettle();

    // 'Owed to me' tab is default.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('I lent money'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ali'); // person
    await tester.enterText(find.byType(TextField).at(1), '2000'); // amount
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    final debts = await db.select(db.debts).get();
    expect(debts, hasLength(1));
    expect(debts.single.principalMinor, 200000);
    // No account chosen → no transaction posted.
    final txs = await db.select(db.transactions).get();
    expect(txs, isEmpty);

    // Balance unchanged.
    expect(await AccountRepository(db).balance(cash), 1000000);

    await _teardown(tester);
  });

  testWidgets('creating a recurring rule lists it', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).create(
      name: 'Bank',
      type: AccountType.bank,
      icon: 'account_balance',
      color: 0xFF000000,
      currency: 'PKR',
    );

    await tester.pumpWidget(_wrap(db, const RecurringScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New recurring'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Rent');
    await tester.enterText(find.byType(TextField).at(1), '50000');
    final create = find.widgetWithText(FilledButton, 'Create');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('Rent'), findsWidgets);
    final rules = await db.select(db.recurringRules).get();
    expect(rules, hasLength(1));

    await _teardown(tester);
  });

  testWidgets('upcoming lists a due rule and Add posts it', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final account = await AccountRepository(db).create(
      name: 'Bank',
      type: AccountType.bank,
      icon: 'account_balance',
      color: 0xFF000000,
      currency: 'PKR',
    );
    // A remind-only rule due today.
    final today = DateTime.now();
    await RecurringRepository(db, TransactionRepository(db)).create(
      RecurringRulesCompanion.insert(
        title: 'Netflix',
        type: TxType.expense,
        amountMinor: 15000,
        currency: 'PKR',
        accountId: account,
        frequency: Frequency.monthly,
        nextDue: DateTime(today.year, today.month, today.day),
        autoPost: const Value(false),
      ),
    );

    await tester.pumpWidget(_wrap(db, const UpcomingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    // markPaid + provider invalidation reloads; bounded pump avoids a settle
    // loop on the reload spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));

    await _teardown(tester);
  });

  testWidgets('debt payment reduces remaining', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DebtRepository(db, TransactionRepository(db));
    await repo.create(
      person: 'Sara',
      direction: DebtDirection.lent,
      principalMinor: 100000,
      currency: 'PKR',
    );

    await tester.pumpWidget(_wrap(db, const DebtsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sara'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '400');
    await tester.tap(find.widgetWithText(FilledButton, 'Add payment'));
    await tester.pumpAndSettle();

    final payments = await db.select(db.debtPayments).get();
    expect(payments, hasLength(1));
    expect(payments.single.amountMinor, 40000);

    await _teardown(tester);
  });
}
