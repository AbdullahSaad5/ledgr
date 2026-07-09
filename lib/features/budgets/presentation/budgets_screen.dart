import 'package:flutter/material.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetsTitle)),
      body: EmptyState(
        icon: Icons.pie_chart_outline,
        title: l10n.budgetsTitle,
        message: l10n.comingSoon,
      ),
    );
  }
}
