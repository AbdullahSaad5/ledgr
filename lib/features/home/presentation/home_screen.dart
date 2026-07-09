import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      body: EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.emptyDashboardTitle,
        message: l10n.emptyDashboardBody,
      ),
    );
  }
}
