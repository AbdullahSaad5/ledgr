import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/core/providers/repository_providers.dart';

/// Shared transaction row actions so every list (home, transactions,
/// account history, search) behaves identically.
void editTransaction(BuildContext context, int id) =>
    context.push('/tx/$id/edit');

Future<void> deleteTransactionWithUndo(
  WidgetRef ref,
  BuildContext context,
  int id,
) async {
  final repo = ref.read(transactionRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  await repo.softDelete(id);
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Transaction deleted'),
      action: SnackBarAction(label: 'Undo', onPressed: () => repo.restore(id)),
    ),
  );
}
