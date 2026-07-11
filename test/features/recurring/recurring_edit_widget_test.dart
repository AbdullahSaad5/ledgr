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

  testWidgets('budget form creates a subcategory budget via scope sheet', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const BudgetFormSheet()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    // Bills & Utilities has seeded children, so tapping it opens the scope
    // sheet instead of selecting directly. The cell sits on the grid's
    // second row, outside its 260px viewport: drag the whole row into view
    // first so the tap lands on the cell's center.
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bills & Utilities').first);
    await tester.pumpAndSettle();
    expect(find.text('All of Bills & Utilities'), findsOneWidget);
    await tester.tap(find.text('Electricity'));
    await tester.pumpAndSettle();
    // The parent's cell now captions the picked child.
    expect(find.text('Electricity'), findsOneWidget);

    // The Limit card can be lazily unbuilt below the fold; bring it in.
    await tester.scrollUntilVisible(
      find.text('Monthly limit'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3000');
    await tester.ensureVisible(find.text('Create budget'));
    await tester.tap(find.text('Create budget'));
    await tester.pumpAndSettle();

    final budgets = await db.select(db.budgets).get();
    final electricity = await (db.select(db.categories)
          ..where((c) => c.name.equals('Electricity')))
        .getSingle();
    expect(budgets.single.categoryId, electricity.id);
    expect(budgets.single.limitMinor, 3000);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('scope sheet "All of parent" budgets the whole parent', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const BudgetFormSheet()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bills & Utilities').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All of Bills & Utilities'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Monthly limit'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '9000');
    await tester.ensureVisible(find.text('Create budget'));
    await tester.tap(find.text('Create budget'));
    await tester.pumpAndSettle();

    final budgets = await db.select(db.budgets).get();
    final bills =
        await (db.select(db.categories)
              ..where((c) => c.name.equals('Bills & Utilities'))
              ..where((c) => c.parentId.isNull()))
            .getSingle();
    expect(budgets.single.categoryId, bills.id);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('budget form edits limit and rollover in place', (
    tester,
  ) async {
    final id = await db
        .into(db.budgets)
        .insert(BudgetsCompanion.insert(limitMinor: 5000));
    final budget = await (db.select(
      db.budgets,
    )..where((b) => b.id.equals(id))).getSingle();

    await tester.pumpWidget(wrap(BudgetFormSheet(budget: budget)));
    await tester.pumpAndSettle();
    expect(find.text('Edit budget'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '8000');
    await tester.tap(find.text('Roll over leftovers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = await (db.select(
      db.budgets,
    )..where((b) => b.id.equals(id))).getSingle();
    expect(updated.limitMinor, 8000);
    expect(updated.rollover, isTrue);

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
