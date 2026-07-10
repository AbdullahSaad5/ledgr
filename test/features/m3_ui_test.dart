import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/budgets/presentation/budgets_screen.dart';
import 'package:ledgr/features/reports/presentation/reports_screen.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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

Future<void> _seed(AppDatabase db) async {
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
      amountMinor: 80000,
      currency: 'PKR',
      accountId: account,
      categoryId: 1,
      date: DateTime.now(),
      payee: 'Cafe',
    ),
  );
}

void main() {
  testWidgets('budgets screen shows a progress bar for a budget', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    await BudgetRepository(db, PeriodResolver(1)).create(limitMinor: 100000);

    await tester.pumpWidget(_wrap(db, const BudgetsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Overall'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('adding a budget via the form persists it', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const BudgetsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add budget'));
    await tester.pumpAndSettle();
    expect(find.text('New budget'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Create budget'));
    await tester.pumpAndSettle();

    final budgets = await db.select(db.budgets).get();
    expect(budgets, hasLength(1));
    expect(budgets.single.limitMinor, 5000); // whole rupees (PKR 0dp)

    await _teardown(tester);
  });

  testWidgets('reports overview renders a pie chart and stats', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);

    await tester.pumpWidget(_wrap(db, const ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.byType(SfCircularChart), findsOneWidget);

    // Trends tab: with a single month of data it shows insight tiles
    // (the month-on-month bar chart needs two active months).
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Daily average'), findsOneWidget);
    expect(find.text('Biggest expense'), findsOneWidget);
    expect(find.byType(SfCartesianChart), findsNothing);

    // Net worth tab renders a line chart.
    await tester.tap(find.text('Net worth'));
    await tester.pumpAndSettle();
    expect(find.byType(SfCartesianChart), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('reports with two months of data render the trend charts', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accounts = AccountRepository(db);
    final cash = await accounts.create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
      openingBalanceMinor: 1000000,
    );
    final bank = await accounts.create(
      name: 'Bank',
      type: AccountType.bank,
      icon: 'account_balance',
      color: 0xFF000000,
      currency: 'PKR',
      openingBalanceMinor: 500000,
    );

    final tx = TransactionRepository(db);
    final now = DateTime.now();
    final lastMonth = now.subtract(const Duration(days: 32));
    Future<void> spend(
      int minor,
      DateTime date, {
      int? categoryId,
      String? payee,
      int? accountId,
    }) => tx.create(
      TransactionDraft(
        type: TxType.expense,
        amountMinor: minor,
        currency: 'PKR',
        accountId: accountId ?? cash,
        categoryId: categoryId,
        date: date,
        payee: payee,
      ),
    );

    // This month: several categories + payees + income.
    await spend(80000, now, categoryId: 1, payee: 'Cafe');
    await spend(45000, now, categoryId: 2, payee: 'Mart');
    await spend(30000, now, payee: 'Cafe', accountId: bank);
    await tx.create(
      TransactionDraft(
        type: TxType.income,
        amountMinor: 500000,
        currency: 'PKR',
        accountId: bank,
        date: now,
        payee: 'Employer',
      ),
    );
    // Last month: enough activity for pace, shift, and month bars.
    await spend(60000, lastMonth, categoryId: 1, payee: 'Cafe');
    await spend(90000, lastMonth, categoryId: 3, payee: 'Careem');

    await tester.pumpWidget(_wrap(db, const ReportsScreen()));
    await tester.pumpAndSettle();

    // Scrolls to the bottom of the current tab so lazily-built sections
    // (top payees, composition bars) actually render.
    Future<void> scrollToBottom() async {
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
    }

    // Overview: daily rhythm bar chart + donut + top payees.
    expect(find.byType(SfCartesianChart), findsWidgets);
    expect(find.byType(SfCircularChart), findsOneWidget);
    await scrollToBottom();
    expect(find.text('Cafe'), findsWidgets);

    // Trends: with a previous month, the pace/month charts render.
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Daily average'), findsOneWidget);
    expect(find.byType(SfCartesianChart), findsWidgets);
    await scrollToBottom();

    // Net worth: line chart + per-account composition.
    await tester.tap(find.text('Net worth'));
    await tester.pumpAndSettle();
    expect(find.byType(SfCartesianChart), findsWidgets);
    await scrollToBottom();
    expect(find.text('Bank'), findsOneWidget);

    await _teardown(tester);
  });
}
