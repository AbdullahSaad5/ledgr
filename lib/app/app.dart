import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:ledgr/features/security/presentation/lock_screen.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

/// Application root: wires dynamic color, Material 3 themes, localization, the
/// router, and the app-lock gate.
class LedgrApp extends ConsumerStatefulWidget {
  const LedgrApp({super.key});

  @override
  ConsumerState<LedgrApp> createState() => _LedgrAppState();
}

class _LedgrAppState extends ConsumerState<LedgrApp>
    with WidgetsBindingObserver {
  final _router = createRouter();
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(lockControllerProvider.notifier);
    final locked = ref.read(appSettingsProvider).lockEnabled;
    switch (state) {
      case AppLifecycleState.paused:
        lock.onPaused(DateTime.now());
      case AppLifecycleState.resumed:
        lock.onResumed(DateTime.now());
        setState(() => _obscured = false);
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Blur the recents snapshot while app-lock is on.
        if (locked) setState(() => _obscured = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final seed = Color(settings.seedColor);
    final locked = ref.watch(lockControllerProvider) && settings.lockEnabled;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = settings.dynamicColor;
        return MaterialApp.router(
          onGenerateTitle: (context) => AppL10n.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            useDynamic ? lightDynamic?.harmonized() : null,
            fallbackSeed: seed,
          ),
          darkTheme: AppTheme.dark(
            useDynamic ? darkDynamic?.harmonized() : null,
            fallbackSeed: seed,
          ),
          themeMode: settings.themeMode,
          routerConfig: _router,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (!settings.onboardingComplete) const OnboardingScreen(),
                if (locked) const LockScreen(),
                if (_obscured && !locked)
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: const ColoredBox(color: Colors.black26),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
