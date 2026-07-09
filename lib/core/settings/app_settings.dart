import 'package:flutter/material.dart';

/// All user-configurable settings. Immutable; persisted by the settings
/// controller.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.dynamicColor = false,
    this.seedColor = 0xFF00696D,
    this.homeCurrency = 'PKR',
    this.currencySymbol = 'Rs ',
    this.monthStartDay = 1,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.lockTimeoutMinutes = 0,
    this.notificationsEnabled = true,
    this.amountsHidden = false,
    this.onboardingComplete = false,
  });

  final ThemeMode themeMode;
  final bool dynamicColor;
  final int seedColor;
  final String homeCurrency;
  final String currencySymbol;
  final int monthStartDay;
  final bool lockEnabled;
  final bool biometricEnabled;
  final int lockTimeoutMinutes;
  final bool notificationsEnabled;
  final bool amountsHidden;
  final bool onboardingComplete;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? dynamicColor,
    int? seedColor,
    String? homeCurrency,
    String? currencySymbol,
    int? monthStartDay,
    bool? lockEnabled,
    bool? biometricEnabled,
    int? lockTimeoutMinutes,
    bool? notificationsEnabled,
    bool? amountsHidden,
    bool? onboardingComplete,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      seedColor: seedColor ?? this.seedColor,
      homeCurrency: homeCurrency ?? this.homeCurrency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      monthStartDay: monthStartDay ?? this.monthStartDay,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      amountsHidden: amountsHidden ?? this.amountsHidden,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
