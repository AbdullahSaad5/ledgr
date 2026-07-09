import 'package:flutter/material.dart';

/// Ledgr's design system: a calm, trustworthy fintech look.
///
/// - **Type**: Manrope everywhere (bundled — the app is offline-first), with
///   tabular figures for money set per-widget in `AmountText`.
/// - **Color**: hand-tuned "paper" light theme and teal-tinted "ink" dark
///   theme built over a deep-teal seed. Dynamic color (Material You) is still
///   honored when the user opts in; typography and shape stay ours.
/// - **Shape**: continuous superellipse corners — 20 for cards, 28 for sheets.
abstract final class AppTheme {
  /// Ledgr's brand seed (deep teal) — used when dynamic color is unavailable.
  static const Color seedColor = Color(0xFF00696D);

  static ThemeData light(ColorScheme? dynamicScheme, {Color? fallbackSeed}) =>
      _themeFor(dynamicScheme ?? _lightScheme(fallbackSeed ?? seedColor));

  static ThemeData dark(ColorScheme? dynamicScheme, {Color? fallbackSeed}) =>
      _themeFor(dynamicScheme ?? _darkScheme(fallbackSeed ?? seedColor));

  /// Fresh mint-neutral light: cool off-white surfaces, white cards, and a
  /// teal-green primary.
  static ColorScheme _lightScheme(Color seed) {
    final base = ColorScheme.fromSeed(seedColor: seed);
    // Only re-skin the neutrals when the user kept the brand seed; a custom
    // seed color keeps its own harmonized neutrals.
    if (seed != seedColor) return base;
    return base.copyWith(
      primary: const Color(0xFF0A6B60),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFBDEBE0),
      onPrimaryContainer: const Color(0xFF00332C),
      surface: const Color(0xFFF2F5F3),
      onSurface: const Color(0xFF17201D),
      onSurfaceVariant: const Color(0xFF48554F),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFCFEFD),
      surfaceContainer: const Color(0xFFE9EFEC),
      surfaceContainerHigh: const Color(0xFFE1E8E5),
      surfaceContainerHighest: const Color(0xFFD9E2DE),
      outlineVariant: const Color(0xFFDDE5E1),
    );
  }

  /// Soft graphite-teal dark: lifted, tinted grays rather than pitch black.
  static ColorScheme _darkScheme(Color seed) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    if (seed != seedColor) return base;
    return base.copyWith(
      primary: const Color(0xFF5BD9C8),
      onPrimary: const Color(0xFF00332C),
      primaryContainer: const Color(0xFF10514B),
      onPrimaryContainer: const Color(0xFFB2F0E4),
      surface: const Color(0xFF151E1C),
      onSurface: const Color(0xFFE4EAE7),
      onSurfaceVariant: const Color(0xFFA0ACA7),
      surfaceContainerLowest: const Color(0xFF101816),
      surfaceContainerLow: const Color(0xFF1B2523),
      surfaceContainer: const Color(0xFF212C29),
      surfaceContainerHigh: const Color(0xFF273330),
      surfaceContainerHighest: const Color(0xFF2E3B37),
      outlineVariant: const Color(0xFF2C3936),
    );
  }

  static ThemeData _themeFor(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = _textTheme(scheme);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Manrope',
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: scheme.primary,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// Manrope scale. Display/headline tighten letter spacing so large money
  /// reads as one confident figure; labels open up slightly for scannability.
  static TextTheme _textTheme(ColorScheme scheme) {
    const family = 'Manrope';
    final base = scheme.brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.75,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0),
          bodySmall: base.bodySmall?.copyWith(letterSpacing: 0.1),
        )
        .apply(fontFamily: family);
  }
}

/// Spacing rhythm — a 4pt grid. Screens use these instead of magic numbers.
abstract final class Gaps {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// Standard horizontal screen inset.
  static const double page = 20;
}

/// Semantic colors for money direction (paired with icons — never color alone,
/// per PLAN.md §7 accessibility).
extension MoneyColors on ColorScheme {
  Color get income => brightness == Brightness.dark
      ? const Color(0xFF6EDB9F)
      : const Color(0xFF1E7A45);

  Color get expense => brightness == Brightness.dark
      ? const Color(0xFFFF8A7A)
      : const Color(0xFFBA3B33);

  Color get warning => brightness == Brightness.dark
      ? const Color(0xFFFFC46B)
      : const Color(0xFFA86B00);

  Color get transfer => onSurfaceVariant;

  /// The dashboard hero panel gradient: deep ink-teal in both themes, derived
  /// from [primary] so dynamic color carries through.
  List<Color> get heroGradient {
    final anchor = brightness == Brightness.dark ? primaryContainer : primary;
    return [
      Color.lerp(anchor, const Color(0xFF0A2724), 0.30)!,
      Color.lerp(anchor, const Color(0xFF071614), 0.65)!,
    ];
  }

  /// Foreground colors that read on [heroGradient] regardless of theme.
  Color get onHero => Colors.white;
  Color get onHeroMuted => Colors.white.withValues(alpha: 0.62);
}
