import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/app.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  runApp(
    UncontrolledProviderScope(container: container, child: const LedgrApp()),
  );
}
