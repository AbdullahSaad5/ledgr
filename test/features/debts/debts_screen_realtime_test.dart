import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/debts/presentation/debts_screen.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';

void main() {
  testWidgets('debts list updates live after a debt is created', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DebtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nobody owes you'), findsOneWidget);

    // Create a debt from outside the widget tree (same db instance), the
    // way the pushed form sheet does.
    await DebtRepository(db, TransactionRepository(db)).create(
      person: 'Ali',
      direction: DebtDirection.lent,
      principalMinor: 5000,
      currency: 'PKR',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Nobody owes you'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
