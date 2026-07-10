import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/settings/app_settings.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/security/data/app_lock_service.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:ledgr/features/security/presentation/lock_screen.dart';
import 'package:ledgr/features/settings/presentation/pin_setup_sheet.dart';

/// In-memory lock service so tests avoid platform secure storage.
class _FakeLock extends AppLockService {
  String? _pin;

  @override
  Future<void> setPin(String pin) async => _pin = pin;

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<bool> verifyPin(String pin) async => pin == _pin;

  @override
  Future<int> pinLength() async => _pin?.length ?? 4;

  @override
  Future<void> clear() async => _pin = null;

  @override
  Future<bool> authenticateBiometric() async => false;
}

/// Settings notifier seeded with lock enabled (so the lock screen shows).
class _LockedSettings extends SettingsController {
  @override
  AppSettings build() => const AppSettings(lockEnabled: true);
}

Widget _wrap(Widget child, {required _FakeLock lock, bool locked = false}) {
  return ProviderScope(
    overrides: [
      appLockServiceProvider.overrideWithValue(lock),
      if (locked) settingsControllerProvider.overrideWith(_LockedSettings.new),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('lock screen shows exactly as many dots as the PIN has digits', (
    tester,
  ) async {
    final lock = _FakeLock();
    await lock.setPin('12345');

    await tester.pumpWidget(_wrap(const LockScreen(), lock: lock));
    await tester.pumpAndSettle();

    // Five dot containers between the title and the keypad (14x14 circles).
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.constraints?.maxWidth == 14 ||
              (c.decoration is BoxDecoration &&
                  (c.decoration! as BoxDecoration).shape == BoxShape.circle),
        )
        .length;
    expect(dots, 5);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('correct PIN unlocks', (tester) async {
    final lock = _FakeLock();
    await lock.setPin('1234');

    late WidgetRef ref;
    await tester.pumpWidget(
      _wrap(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return const LockScreen();
          },
        ),
        lock: lock,
        locked: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(ref.read(lockControllerProvider), isTrue); // starts locked
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(ref.read(lockControllerProvider), isFalse); // unlocked
  });

  testWidgets('wrong PIN clears and stays locked', (tester) async {
    final lock = _FakeLock();
    await lock.setPin('1234');

    late WidgetRef ref;
    await tester.pumpWidget(
      _wrap(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return const LockScreen();
          },
        ),
        lock: lock,
        locked: true,
      ),
    );
    await tester.pumpAndSettle();

    for (final d in ['9', '9', '9', '9']) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(ref.read(lockControllerProvider), isTrue);
    expect(find.text('Wrong PIN, try again'), findsOneWidget);
  });

  testWidgets('PIN setup saves matching PINs', (tester) async {
    final lock = _FakeLock();
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PinSetupSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
        lock: lock,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '4321');
    await tester.enterText(find.byType(TextField).at(1), '4321');
    await tester.tap(find.widgetWithText(FilledButton, 'Save PIN'));
    await tester.pumpAndSettle();

    expect(await lock.verifyPin('4321'), isTrue);
  });
}
