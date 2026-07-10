import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/budgets/presentation/budget_form_sheet.dart';
import 'package:ledgr/features/recurring/presentation/recurring_form_sheet.dart';

void main() {
  late AppDatabase db;
  late int cash;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cash = await AccountRepository(db).create(
      name: 'Cash',
      type: AccountType.cash,
      icon: 'payments',
      color: 0xFF000000,
      currency: 'PKR',
    );
  });
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: child),
  );

  testWidgets('recurring form edits an existing rule in place', (
    tester,
  ) async {
    final id = await db
        .into(db.recurringRules)
        .insert(
          RecurringRulesCompanion.insert(
            title: 'Netflix',
            type: TxType.expense,
            amountMinor: 1500,
            currency: 'PKR',
            accountId: cash,
            frequency: Frequency.monthly,
            nextDue: DateTime(2026, 8, 1),
            anchorDay: const Value(1),
          ),
        );
    final rule = await (db.select(
      db.recurringRules,
    )..where((r) => r.id.equals(id))).getSingle();

    await tester.pumpWidget(wrap(RecurringFormSheet(rule: rule)));
    await tester.pumpAndSettle();

    expect(find.text('Edit recurring'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Netflix Premium');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = await (db.select(
      db.recurringRules,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(updated.title, 'Netflix Premium');
    expect(updated.amountMinor, 1500);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('budget form creates a rollover category budget', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const BudgetFormSheet()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    // Pick the first seeded category cell from the grid.
    await tester.ensureVisible(find.text('Food & Dining').first);
    await tester.tap(find.text('Food & Dining').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.text('Roll over leftovers'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create budget'));
    await tester.tap(find.text('Create budget'));
    await tester.pumpAndSettle();

    final budgets = await db.select(db.budgets).get();
    expect(budgets, hasLength(1));
    expect(budgets.single.limitMinor, 5000);
    expect(budgets.single.rollover, isTrue);
    expect(budgets.single.categoryId, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
