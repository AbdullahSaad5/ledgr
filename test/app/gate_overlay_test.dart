import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/app/app.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression: the onboarding/lock gates must host their own Overlay so their
/// text fields work. Booting fresh (onboarding not complete) and typing into a
/// field previously threw "No Overlay widget found".
void main() {
  testWidgets('onboarding gate text fields have an Overlay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const LedgrApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Onboarding is shown over the app.
    expect(find.text('Welcome to Ledgr'), findsOneWidget);

    // Advance to the accounts page and type into a field (needs an Overlay).
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pumpAndSettle();

    // No "No Overlay widget found" exception was thrown.
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
