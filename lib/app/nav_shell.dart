import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/app/router.dart';
import 'package:ledgr/app/widgets/ledgr_nav_bar.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The persistent navigation shell (PLAN.md §6.1): four destinations in a
/// floating pill bar with the log-transaction FAB set into its center.
class NavShell extends StatelessWidget {
  const NavShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: LedgrNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: _goBranch,
        onFab: () => context.pushNamed(AppRoute.addTransaction.name),
        items: [
          LedgrNavItem(icon: LucideIcons.home, label: l10n.navHome),
          LedgrNavItem(icon: LucideIcons.receipt, label: l10n.navTransactions),
          LedgrNavItem(icon: LucideIcons.pieChart, label: l10n.navBudgets),
          LedgrNavItem(icon: LucideIcons.barChart3, label: l10n.navReports),
        ],
      ),
    );
  }
}
