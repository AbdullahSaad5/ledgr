import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/app.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/backup/data/auto_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Run at the display's highest refresh rate (Android; no-op elsewhere).
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } on Exception catch (_) {
      // Not supported on this device — 60Hz is fine.
    }
  }
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  await container.read(notificationServiceProvider).init();
  // Post any recurring transactions that came due while the app was closed.
  await container.read(recurringRepositoryProvider).catchUp(DateTime.now());
  // Converge debt due-date reminders with the current debt set (#17).
  await container.read(debtReminderServiceProvider).syncAll();
  // Daily local auto-backup (#17): the task itself no-ops when disabled,
  // and enable() keeps existing schedules, so this is idempotent.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Workmanager().initialize(autoBackupDispatcher);
    if (container.read(appSettingsProvider).autoBackupEnabled) {
      await const AutoBackupService().enable();
    }
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const LedgrApp()),
  );
}
