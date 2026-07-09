import 'package:flutter/material.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

/// Placeholder for the add/edit transaction flow (built in M1). Presented as a
/// full-screen route from the shell FAB.
class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navAdd), leading: const CloseButton()),
      body: EmptyState(
        icon: Icons.add_card_outlined,
        title: l10n.navAdd,
        message: l10n.comingSoon,
      ),
    );
  }
}
