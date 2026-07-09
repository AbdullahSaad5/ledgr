import 'package:flutter/material.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: EmptyState(
        icon: Icons.bar_chart_outlined,
        title: l10n.reportsTitle,
        message: l10n.comingSoon,
      ),
    );
  }
}
