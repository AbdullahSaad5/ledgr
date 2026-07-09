import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/app/app.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _bootApp(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const LedgrApp(),
  );
}

/// Tears down the widget tree so Drift stream subscriptions cancel and their
/// close timers drain before the test framework checks for pending timers.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // Skip onboarding + lock in these navigation tests.
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('boots to the dashboard', (tester) async {
    await tester.pumpWidget(_bootApp(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('bottom navigation switches branches', (tester) async {
    await tester.pumpWidget(_bootApp(prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing this month'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.text('No budgets yet'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('the FAB opens the add-transaction screen', (tester) async {
    await tester.pumpWidget(_bootApp(prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New transaction'), findsOneWidget);

    await _teardown(tester);
  });
}
