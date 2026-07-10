import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/features/attachments/data/attachment_repository.dart';
import 'package:ledgr/features/transactions/presentation/tx_actions.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Read-only transaction detail with edit / duplicate / delete actions.
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({required this.transactionId, super.key});

  final int transactionId;

  static Future<void> show(BuildContext context, int id) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionDetailSheet(transactionId: id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionByIdProvider(transactionId));
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return txAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(height: 200, child: Center(child: Text('$e'))),
      data: (tx) {
        final category = tx.categoryId == null
            ? null
            : categories[tx.categoryId];
        final (IconData icon, Color tint, String title) = switch (tx.type) {
          TxType.transfer => (
            LucideIcons.arrowLeftRight,
            scheme.transfer,
            tx.payee ?? 'Transfer',
          ),
          TxType.adjustment => (
            LucideIcons.slidersHorizontal,
            scheme.onSurfaceVariant,
            tx.note ?? 'Adjustment',
          ),
          _ => (
            AppIcons.resolve(category?.icon ?? 'category'),
            category == null ? scheme.onSurfaceVariant : Color(category.color),
            tx.payee ?? category?.name ?? 'Transaction',
          ),
        };
        final tone = switch (tx.type) {
          TxType.income => AmountTone.income,
          TxType.expense => AmountTone.expense,
          _ => AmountTone.neutral,
        };
        final accountLabel = tx.type == TxType.transfer
            ? '${accounts[tx.accountId]?.name ?? 'Account'} → '
                  '${accounts[tx.toAccountId]?.name ?? 'Account'}'
            : accounts[tx.accountId]?.name ?? 'Account';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(icon: icon, color: tint, size: 56, iconSize: 24),
              const SizedBox(height: Gaps.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(
                  tx.amount,
                  formatter: formatter,
                  tone: tone,
                  showPlus: tx.type == TxType.income,
                  style: text.headlineMedium,
                ),
              ),
              Text(
                title,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gaps.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gaps.lg,
                    vertical: Gaps.sm,
                  ),
                  child: Column(
                    children: [
                      _row(
                        context,
                        LucideIcons.wallet,
                        tx.type == TxType.transfer ? 'Between' : 'Account',
                        accountLabel,
                      ),
                      if (category != null)
                        _row(
                          context,
                          LucideIcons.shapes,
                          'Category',
                          category.name,
                        ),
                      _row(
                        context,
                        LucideIcons.calendar,
                        'Date',
                        DateFormat('EEE, d MMM yyyy').format(tx.date),
                      ),
                      if (tx.fee != null && tx.fee!.minor > 0)
                        _row(
                          context,
                          LucideIcons.receipt,
                          'Fee',
                          formatter.format(tx.fee!),
                        ),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _row(
                          context,
                          LucideIcons.notebookPen,
                          'Note',
                          tx.note!,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gaps.md),
              _ReceiptsSection(transactionId: tx.id),
              const SizedBox(height: Gaps.lg),
              Row(
                children: [
                  _ActionTile(
                    icon: LucideIcons.pencil,
                    label: 'Edit',
                    onTap: () {
                      Navigator.of(context).pop();
                      editTransaction(context, tx.id);
                    },
                  ),
                  const SizedBox(width: Gaps.sm),
                  _ActionTile(
                    icon: LucideIcons.copy,
                    label: 'Duplicate',
                    onTap: () async {
                      await ref
                          .read(transactionRepositoryProvider)
                          .duplicate(tx.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: Gaps.sm),
                  _ActionTile(
                    icon: LucideIcons.trash2,
                    label: 'Delete',
                    destructive: true,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await deleteTransactionWithUndo(ref, context, tx.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Gaps.md),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: Gaps.md),
          // Expanded (not Spacer + Flexible, which split the free space and
          // left the value floating mid-row): value hugs the right edge.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Equal-width soft action button for the sheet's action row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.expense : scheme.onSurface;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Expanded(
      child: Material(
        color: destructive
            ? scheme.expense.withValues(alpha: 0.10)
            : scheme.surfaceContainer,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gaps.md),
            child: Column(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Receipt photos attached to this transaction: thumbnail strip plus an
/// add tile (camera or gallery). Images live in app-private storage — see
/// AttachmentRepository.
class _ReceiptsSection extends ConsumerWidget {
  const _ReceiptsSection({required this.transactionId});

  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments =
        ref.watch(attachmentsProvider(transactionId)).valueOrNull ??
        const <Attachment>[];
    final repo = ref.read(attachmentRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipts',
          style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Gaps.sm),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final a in attachments)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Gaps.sm),
                  child: _ReceiptThumb(attachment: a, repo: repo),
                ),
              InkWell(
                customBorder: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => _pickAndAttach(context, ref),
                child: Container(
                  width: 72,
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainer,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.imagePlus,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndAttach(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, size: 20),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, size: 20),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;
    await ref
        .read(attachmentRepositoryProvider)
        .add(transactionId, sourcePath: picked.path);
  }
}

class _ReceiptThumb extends ConsumerWidget {
  const _ReceiptThumb({required this.attachment, required this.repo});

  final Attachment attachment;
  final AttachmentRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<File>(
      future: repo.fileFor(attachment),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null || !file.existsSync()) {
          return Container(
            width: 72,
            decoration: ShapeDecoration(
              color: scheme.surfaceContainer,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
        return InkWell(
          customBorder: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: () => _view(context, ref, file),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Future<void> _view(BuildContext context, WidgetRef ref, File file) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(Gaps.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.7,
              ),
              child: InteractiveViewer(child: Image.file(file)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(attachmentRepositoryProvider)
                        .remove(attachment.id);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text('Remove'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
