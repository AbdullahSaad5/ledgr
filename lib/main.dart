import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/app.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
