import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/notifications/notification_service.dart';
import 'package:ledgr/features/debts/data/debt_reminder_service.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';

/// Records schedule/cancel calls instead of touching the platform plugin.
class _RecordingNotifications extends NotificationService {
  final scheduled = <int, DateTime>{};
  final cancelled = <int>[];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String channelId = 'ledgr_reminders',
    String channelName = 'Reminders',
  }) async {
    scheduled[id] = when;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

void main() {
  late AppDatabase db;
  late DebtRepository debts;
  late _RecordingNotifications notifications;
  late DebtReminderService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    debts = DebtRepository(db, TransactionRepository(db));
    notifications = _RecordingNotifications();
    service = DebtReminderService(
      db,
      notifications,
      const MoneyFormatter(symbol: 'Rs ', locale: 'en'),
    );
  });
  tearDown(() => db.close());

  test('schedules 9am reminders for unsettled debts with due dates', () async {
    final due = DateTime.now().add(const Duration(days: 10));
    final id = await debts.create(
      person: 'Ali',
      direction: DebtDirection.lent,
      principalMinor: 5000,
      currency: 'PKR',
      dueDate: due,
    );
    await service.syncAll();

    final when = notifications.scheduled[DebtReminderService.idBase + id];
    expect(when, isNotNull);
    expect((when!.year, when.month, when.day, when.hour), (
      due.year,
      due.month,
      due.day,
      9,
    ));
  });

  test('update edits person, due date, and note', () async {
    final id = await debts.create(
      person: 'Alii',
      direction: DebtDirection.lent,
      principalMinor: 5000,
      currency: 'PKR',
    );
    final due = DateTime(2026, 8, 1);
    await debts.update(id, person: 'Ali', dueDate: due, note: 'chai money');

    final all = await debts.watchByDirection(DebtDirection.lent).first;
    final debt = all.single.debt;
    expect(debt.person, 'Ali');
    expect(
      (debt.dueDate!.year, debt.dueDate!.month, debt.dueDate!.day),
      (2026, 8, 1),
    );
    expect(debt.note, 'chai money');
  });

  test('cancels reminders for settled debts and debts without dates', () async {
    final withDate = await debts.create(
      person: 'Bilal',
      direction: DebtDirection.borrowed,
      principalMinor: 9000,
      currency: 'PKR',
      dueDate: DateTime.now().add(const Duration(days: 3)),
    );
    final noDate = await debts.create(
      person: 'Sara',
      direction: DebtDirection.lent,
      principalMinor: 700,
      currency: 'PKR',
    );
    // Settle the first debt by paying it off.
    final all = await debts.watchByDirection(DebtDirection.borrowed).first;
    await debts.addPayment(all.single, amountMinor: 9000);

    await service.syncAll();

    expect(
      notifications.cancelled,
      containsAll([
        DebtReminderService.idBase + withDate,
        DebtReminderService.idBase + noDate,
      ]),
    );
    expect(notifications.scheduled, isEmpty);
  });
}
