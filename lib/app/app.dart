import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
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
  }

  /// Builds the full widget snapshot (net worth, month totals, overall
  /// budget, recent lines, today's spend) and pushes it to both widgets.
  Future<void> _syncHomeWidgets() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final formatter = ref.read(moneyFormatterProvider);
      final currency = ref.read(appSettingsProvider).homeCurrency;
      String money(int minor) =>
          formatter.format(Money(minor: minor, currency: currency));

      final now = DateTime.now();
      final period = ref.read(periodResolverProvider).periodContaining(now);
      final reports = ref.read(reportsRepositoryProvider);

      final accounts = await ref
          .read(accountRepositoryProvider)
          .watchActiveWithBalances()
          .first;
      final netWorth = accounts
          .where((a) => a.account.includeInNetWorth)
          .fold(0, (s, a) => s + a.balanceMinor);

      final totals = await reports.monthTotals(period);

      final budgets = await ref
          .read(budgetRepositoryProvider)
          .watchProgress(period)
          .first;
      final overallMatches = budgets.where((b) => b.isOverall);
      final budget = overallMatches.isNotEmpty
          ? overallMatches.first
          : (budgets.isNotEmpty ? budgets.first : null);

      final txs = await ref
          .read(transactionRepositoryProvider)
          .watchInPeriod(period)
          .first;
      final categories = ref.read(categoryMapProvider);
      String txTitle(Transaction t) =>
          t.payee ?? categories[t.categoryId]?.name ?? t.type.name;
      final today = txs.where(
        (t) =>
            t.type == TxType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day,
      );
      final todaySpent = today.fold(0, (s, t) => s + t.amountMinor);

      final start = period.start;
      final endDay = period.end.subtract(const Duration(days: 1));

      await HomeWidgetSync.push(
        netWorth: money(netWorth),
        periodLabel:
            '${DateFormat('d MMM').format(start)} – '
            '${DateFormat('d MMM').format(endDay)}',
        spent: money(totals.expenseMinor),
        received: money(totals.incomeMinor),
        todaySpent: money(todaySpent),
        budgetLabel: budget == null
            ? null
            : '${budget.isOverall ? 'Overall budget' : 'Budget'} · '
                  '${money(budget.spentMinor)} of '
                  '${money(budget.effectiveLimitMinor)}',
        budgetPct: budget == null ? -1 : (budget.fraction * 100).round(),
        tx1Title: txs.isNotEmpty ? txTitle(txs[0]) : '',
        tx1Amount: txs.isNotEmpty ? money(txs[0].amountMinor) : '',
        tx2Title: txs.length > 1 ? txTitle(txs[1]) : '',
        tx2Amount: txs.length > 1 ? money(txs[1].amountMinor) : '',
      );
    } on Object {
      // Snapshot building is best-effort; widgets just stay stale.
    }
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
    // Keep the home-screen widgets current with every balance change (the
    // accounts stream fires on any money-affecting write).
    ref
      ..listen(activeAccountsProvider, (_, next) {
        if (next.valueOrNull != null) _syncHomeWidgets();
      })
      ..listen(budgetProgressProvider, (_, next) {
        if (next.valueOrNull != null) _syncHomeWidgets();
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
