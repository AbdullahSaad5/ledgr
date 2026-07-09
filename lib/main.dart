import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/app.dart';
import 'package:ledgr/core/providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(notificationServiceProvider).init();
  // Post any recurring transactions that came due while the app was closed.
  await container.read(recurringRepositoryProvider).catchUp(DateTime.now());
  runApp(
    UncontrolledProviderScope(container: container, child: const LedgrApp()),
  );
}
