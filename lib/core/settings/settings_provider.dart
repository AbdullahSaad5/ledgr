import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/settings/app_settings.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app overrides this at startup with a loaded instance. Left null in
/// tests, where settings fall back to defaults and writes are no-ops.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// The reactive settings store, persisted to SharedPreferences.
class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'themeMode';
  static const _kDynamic = 'dynamicColor';
  static const _kSeed = 'seedColor';
  static const _kCurrency = 'homeCurrency';
  static const _kSymbol = 'currencySymbol';
  static const _kMonthStart = 'monthStartDay';
  static const _kLock = 'lockEnabled';
  static const _kBiometric = 'biometricEnabled';
  static const _kTimeout = 'lockTimeoutMinutes';
  static const _kNotifications = 'notificationsEnabled';
  static const _kOnboarding = 'onboardingComplete';
  static const _kAutoBackup = 'autoBackupEnabled';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final p = _prefs;
    const d = AppSettings();
    if (p == null) return d;
    return AppSettings(
      themeMode: ThemeMode.values[p.getInt(_kTheme) ?? d.themeMode.index],
      dynamicColor: p.getBool(_kDynamic) ?? d.dynamicColor,
      seedColor: p.getInt(_kSeed) ?? d.seedColor,
      homeCurrency: p.getString(_kCurrency) ?? d.homeCurrency,
      currencySymbol: p.getString(_kSymbol) ?? d.currencySymbol,
      monthStartDay: p.getInt(_kMonthStart) ?? d.monthStartDay,
      lockEnabled: p.getBool(_kLock) ?? d.lockEnabled,
      biometricEnabled: p.getBool(_kBiometric) ?? d.biometricEnabled,
      lockTimeoutMinutes: p.getInt(_kTimeout) ?? d.lockTimeoutMinutes,
      notificationsEnabled:
          p.getBool(_kNotifications) ?? d.notificationsEnabled,
      onboardingComplete: p.getBool(_kOnboarding) ?? d.onboardingComplete,
      autoBackupEnabled: p.getBool(_kAutoBackup) ?? d.autoBackupEnabled,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setInt(_kTheme, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDynamicColor({required bool enabled}) async {
    await _prefs?.setBool(_kDynamic, enabled);
    state = state.copyWith(dynamicColor: enabled);
  }

  Future<void> setSeedColor(int value) async {
    await _prefs?.setInt(_kSeed, value);
    state = state.copyWith(seedColor: value);
  }

  Future<void> setCurrency(String code, String symbol) async {
    await _prefs?.setString(_kCurrency, code);
    await _prefs?.setString(_kSymbol, symbol);
    state = state.copyWith(homeCurrency: code, currencySymbol: symbol);
  }

  Future<void> setMonthStartDay(int day) async {
    await _prefs?.setInt(_kMonthStart, day);
    state = state.copyWith(monthStartDay: day);
  }

  Future<void> setLockEnabled({required bool enabled}) async {
    await _prefs?.setBool(_kLock, enabled);
    state = state.copyWith(lockEnabled: enabled);
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    await _prefs?.setBool(_kBiometric, enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setLockTimeout(int minutes) async {
    await _prefs?.setInt(_kTimeout, minutes);
    state = state.copyWith(lockTimeoutMinutes: minutes);
  }

  Future<void> setNotificationsEnabled({required bool enabled}) async {
    await _prefs?.setBool(_kNotifications, enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  Future<void> setAutoBackupEnabled({required bool enabled}) async {
    await _prefs?.setBool(_kAutoBackup, enabled);
    state = state.copyWith(autoBackupEnabled: enabled);
  }

  Future<void> setOnboardingComplete() async {
    await _prefs?.setBool(_kOnboarding, true);
    state = state.copyWith(onboardingComplete: true);
  }

  /// Amount-blur is session-only (not persisted) — a privacy glance toggle.
  void toggleAmountsHidden() {
    state = state.copyWith(amountsHidden: !state.amountsHidden);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Backwards-compatible read alias used across the app.
final appSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsControllerProvider),
);

final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return MoneyFormatter(symbol: settings.currencySymbol);
});

final periodResolverProvider = Provider<PeriodResolver>(
  (ref) => PeriodResolver(ref.watch(appSettingsProvider).monthStartDay),
);
