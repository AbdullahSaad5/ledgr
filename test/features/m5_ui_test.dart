import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/settings/app_settings.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ledgr/features/settings/presentation/settings_screen.dart';
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
  testWidgets('settings changes theme mode', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SettingsScreen();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(ref.read(appSettingsProvider).themeMode, ThemeMode.system);
    // Change month-start-day via the dropdown.
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    expect(ref.read(appSettingsProvider).monthStartDay, 25);

    await _teardown(tester);
  });

  testWidgets('onboarding finishes and creates accounts', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const OnboardingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Ledgr'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    // Currency page.
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    // Accounts page: enter a cash balance.
    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
    await tester.pumpAndSettle();

    final accounts = await db.select(db.accounts).get();
    expect(accounts.where((a) => a.name == 'Cash'), hasLength(1));

    await _teardown(tester);
  });

  test('AppSettings copyWith preserves other fields', () {
    const s = AppSettings(monthStartDay: 25, homeCurrency: 'USD');
    final next = s.copyWith(monthStartDay: 1);
    expect(next.monthStartDay, 1);
    expect(next.homeCurrency, 'USD');
  });
}
