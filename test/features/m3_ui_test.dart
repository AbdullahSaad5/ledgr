import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/budgets/presentation/budgets_screen.dart';
import 'package:ledgr/features/reports/presentation/reports_screen.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';
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
    await BudgetRepository(db).create(limitMinor: 100000);

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
    expect(budgets.single.limitMinor, 500000);

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
    expect(find.byType(PieChart), findsOneWidget);

    // Trends tab: with a single month of data it shows insight tiles
    // (the month-on-month bar chart needs two active months).
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Daily average'), findsOneWidget);
    expect(find.text('Biggest expense'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);

    // Net worth tab renders a line chart.
    await tester.tap(find.text('Net worth'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);

    await _teardown(tester);
  });
}
