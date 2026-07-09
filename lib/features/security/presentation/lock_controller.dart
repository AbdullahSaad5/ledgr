import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/security/data/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(),
);

/// Whether the app is currently locked. Starts locked when app-lock is enabled.
class LockController extends Notifier<bool> {
  DateTime? _pausedAt;

  @override
  bool build() => ref.read(appSettingsProvider).lockEnabled;

  void unlock() => state = false;

  void lock() => state = true;

  /// Record when the app went to background.
  void onPaused(DateTime at) => _pausedAt = at;

  /// On resume, re-lock if app-lock is on and the background timeout elapsed.
  void onResumed(DateTime at) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.lockEnabled) return;
    final since = _pausedAt;
    if (since == null) return;
    final minutes = at.difference(since).inMinutes;
    if (minutes >= settings.lockTimeoutMinutes) {
      state = true;
    }
    _pausedAt = null;
  }
}

final lockControllerProvider = NotifierProvider<LockController, bool>(
  LockController.new,
);
