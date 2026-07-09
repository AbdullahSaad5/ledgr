import 'package:flutter/material.dart';

/// Material 3 theming. Uses dynamic color when the platform provides it
/// (wired in the app root); otherwise falls back to [seedColor].
abstract final class AppTheme {
  /// Ledgr's brand seed (deep teal) — used when dynamic color is unavailable.
  static const Color seedColor = Color(0xFF00696D);

  static ThemeData light(ColorScheme? dynamicScheme) =>
      _themeFor(dynamicScheme ?? ColorScheme.fromSeed(seedColor: seedColor));

  static ThemeData dark(ColorScheme? dynamicScheme) => _themeFor(
    dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  );

  static ThemeData _themeFor(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Tabular figures so amounts align in columns (PLAN.md §7).
      textTheme: const TextTheme().apply(fontFamilyFallback: const []),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        backgroundColor: scheme.surface,
      ),
    );
  }
}

/// Semantic colors for money direction (paired with icons — never color alone,
/// per PLAN.md §7 accessibility).
extension MoneyColors on ColorScheme {
  Color get income => brightness == Brightness.dark
      ? const Color(0xFF7CD9A0)
      : const Color(0xFF2E7D32);

  Color get expense => error;

  Color get transfer => onSurfaceVariant;
}
