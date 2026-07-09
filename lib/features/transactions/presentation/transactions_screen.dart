import 'package:flutter/material.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactionsTitle)),
      body: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.transactionsTitle,
        message: l10n.comingSoon,
      ),
    );
  }
}
