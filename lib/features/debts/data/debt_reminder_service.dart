import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/notifications/notification_service.dart';

/// Schedules a local notification for every unsettled debt with a due date
/// (9:00 on the day it's due) and cancels reminders that no longer apply.
/// Idempotent: re-running after any debt change converges to the right set,
/// so callers just fire [syncAll] after mutations and on app start (#17).
class DebtReminderService {
  DebtReminderService(this._db, this._notifications, this._formatter);

  /// Keeps reminder ids clear of budget-alert ids (those use budget row ids).
  static const idBase = 100000;

  final AppDatabase _db;
  final NotificationService _notifications;
  final MoneyFormatter _formatter;

  Future<void> syncAll() async {
    final debts = await (_db.select(
      _db.debts,
    )..where((d) => d.deletedAt.isNull())).get();

    for (final debt in debts) {
      final id = idBase + debt.id;
      final due = debt.dueDate;
      if (debt.settled || due == null) {
        await _notifications.cancel(id);
        continue;
      }
      final paid = await _paidFor(debt.id);
      final remaining = _formatter.format(
        Money(minor: debt.principalMinor - paid, currency: debt.currency),
      );
      final lent = debt.direction == DebtDirection.lent;
      await _notifications.schedule(
        id: id,
        title: lent ? 'Debt due today' : 'Repayment due today',
        body: lent
            ? '${debt.person} owes you $remaining.'
            : 'You owe ${debt.person} $remaining.',
        when: DateTime(due.year, due.month, due.day, 9),
      );
    }
  }

  Future<int> _paidFor(int debtId) async {
    final amount = _db.debtPayments.amountMinor.sum();
    final row =
        await (_db.selectOnly(_db.debtPayments)
              ..addColumns([amount])
              ..where(_db.debtPayments.debtId.equals(debtId)))
            .getSingle();
    return row.read(amount) ?? 0;
  }
}
