import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A single transaction row (transactions list + account history).
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    required this.formatter,
    this.category,
    this.accountName,
    this.perspectiveAccountId,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.selected = false,
    super.key,
  });

  final Transaction transaction;
  final MoneyFormatter formatter;
  final Category? category;
  final String? accountName;

  /// When set, the amount is shown as its signed effect on this account
  /// (account-history view); otherwise by the transaction's own type.
  final int? perspectiveAccountId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// When provided, the row can be swiped left to reveal edit/delete.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = transaction;

    final (IconData icon, Color tint, String title) = switch (t.type) {
      TxType.transfer => (
        LucideIcons.arrowLeftRight,
        scheme.transfer,
        t.payee ?? 'Transfer',
      ),
      TxType.adjustment => (
        LucideIcons.slidersHorizontal,
        scheme.onSurfaceVariant,
        t.note ?? 'Adjustment',
      ),
      _ => (
        AppIcons.resolve(category?.icon ?? 'category'),
        category == null ? scheme.onSurfaceVariant : Color(category!.color),
        t.payee ?? category?.name ?? 'Transaction',
      ),
    };

    final money = perspectiveAccountId != null
        ? t.signedAmountFor(perspectiveAccountId!)
        : t.amount;
    final tone = switch (t.type) {
      TxType.income => AmountTone.income,
      TxType.expense => AmountTone.expense,
      _ => perspectiveAccountId != null ? AmountTone.auto : AmountTone.neutral,
    };

    final subtitle = [
      if (accountName != null) accountName!,
      if (t.note != null && t.note!.isNotEmpty && t.type != TxType.adjustment)
        t.note!,
    ].join(' · ');

    final tile = ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: selected
          ? IconBadge.filled(
              icon: LucideIcons.check,
              fill: scheme.primary,
              onColor: scheme.onPrimary,
            )
          : IconBadge(icon: icon, color: tint, iconSize: 20),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: AmountText(
        money,
        formatter: formatter,
        tone: tone,
        showPlus: t.type == TxType.income,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );

    if (onEdit == null && onDelete == null) return tile;
    return Slidable(
      key: ValueKey('tx-${t.id}'),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.42,
        children: [
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit!(),
              backgroundColor: scheme.surfaceContainerHigh,
              foregroundColor: scheme.onSurface,
              icon: LucideIcons.pencil,
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete!(),
              backgroundColor: scheme.expense.withValues(alpha: 0.16),
              foregroundColor: scheme.expense,
              icon: LucideIcons.trash2,
            ),
        ],
      ),
      child: tile,
    );
  }
}
