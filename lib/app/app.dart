import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ledgr/app/router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/home_widget/home_widget_sync.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:ledgr/features/security/presentation/lock_screen.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';
import 'package:quick_actions/quick_actions.dart';

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
    _initQuickActions();
    _initHomeWidget();
  }

  /// Home-screen widget: the + button deep-links into the keypad.
  void _initHomeWidget() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetUri);
      HomeWidget.widgetClicked.listen(_onWidgetUri);
    } on Exception catch (_) {
      // Widget plumbing is best-effort; never block startup.
    }
  }

  void _onWidgetUri(Uri? uri) {
    if (uri != null && uri.host == 'add') _router.push('/tx/new');
  }

  /// Launcher long-press shortcut: jump straight into the keypad.
  void _initQuickActions() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      const QuickActions()
        ..initialize((type) {
          if (type == 'log_expense') _router.push('/tx/new');
        })
        ..setShortcutItems(const [
          ShortcutItem(type: 'log_expense', localizedTitle: 'Log expense'),
        ]);
    } on Exception catch (_) {
      // Shortcuts are best-effort; never block startup.
    }
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
    // Keep the home-screen widget's number current with every balance change.
    ref.listen(activeAccountsProvider, (_, next) {
      final accounts = next.valueOrNull;
      if (accounts == null) return;
      final total = accounts
          .where((a) => a.account.includeInNetWorth)
          .fold(0, (s, a) => s + a.balanceMinor);
      final formatter = ref.read(moneyFormatterProvider);
      final currency = ref.read(appSettingsProvider).homeCurrency;
      HomeWidgetSync.push(
        netWorth: formatter.format(Money(minor: total, currency: currency)),
      );
    });
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
                // Gate screens run in their own Navigator so their text fields,
                // dropdowns, and sheets have an Overlay in scope.
                if (!settings.onboardingComplete)
                  _gate(const OnboardingScreen()),
                if (locked) _gate(const LockScreen()),
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

  /// Hosts a full-screen gate (onboarding / lock) in its own Navigator so it
  /// gets an Overlay, independent of the router's navigator.
  Widget _gate(Widget screen) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}
