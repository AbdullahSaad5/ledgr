import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/features/recurring/domain/recurring_schedule.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

/// A rule occurrence expected on a date (upcoming view).
class UpcomingItem {
  const UpcomingItem({required this.rule, required this.date});
  final RecurringRule rule;
  final DateTime date;

  bool get isOverdue => date.isBefore(
    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
  );
}

/// Recurring rules and the posting engine (PLAN.md §3.1/§4).
class RecurringRepository {
  RecurringRepository(this._db, this._tx);

  final AppDatabase _db;
  final TransactionRepository _tx;

  Stream<List<RecurringRule>> watchActive() => _activeQuery().watch();

  Future<List<RecurringRule>> activeRules() => _activeQuery().get();

  SimpleSelectStatement<$RecurringRulesTable, RecurringRule> _activeQuery() {
    return _db.select(_db.recurringRules)
      ..where((r) => r.active.equals(true) & r.deletedAt.isNull())
      ..orderBy([(r) => OrderingTerm(expression: r.nextDue)]);
  }

  Future<int> create(RecurringRulesCompanion rule) =>
      _db.into(_db.recurringRules).insert(rule);

  Future<void> update(int id, RecurringRulesCompanion rule) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        rule.copyWith(updatedAt: Value(DateTime.now())),
      );

  Future<void> delete(int id) {
    return (_db.update(
      _db.recurringRules,
    )..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setActive(int id, {required bool active}) {
    return (_db.update(
      _db.recurringRules,
    )..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Posts every due occurrence of every **auto-post** rule up to [now],
  /// exactly once (the loop advances and persists `nextDue`, so a second run
  /// finds nothing due). Returns the number of transactions posted.
  Future<int> catchUp(DateTime now) async {
    final rules = await activeRules();
    var posted = 0;
    for (final rule in rules) {
      if (!rule.autoPost) continue;
      var nextDue = rule.nextDue;
      var remaining = rule.remainingCount;
      var active = true;

      while (!nextDue.isAfter(now)) {
        if (rule.endDate != null && nextDue.isAfter(rule.endDate!)) {
          active = false;
          break;
        }
        await _post(rule, nextDue);
        posted++;
        nextDue = _advance(rule, nextDue);
        if (remaining != null) {
          remaining -= 1;
          if (remaining <= 0) {
            active = false;
            break;
          }
        }
      }
      await _persist(rule.id, nextDue, remaining, active: active);
    }
    return posted;
  }

  /// Post the current occurrence now (remind-only "Add now" / upcoming
  /// mark-paid) and advance the schedule by one.
  Future<void> markPaid(RecurringRule rule) async {
    await _post(rule, DateTime.now());
    final remaining = rule.remainingCount == null
        ? null
        : rule.remainingCount! - 1;
    final active = remaining == null || remaining > 0;
    await _persist(
      rule.id,
      _advance(rule, rule.nextDue),
      remaining,
      active: active,
    );
  }

  /// Skip this occurrence without posting.
  Future<void> skip(RecurringRule rule) async {
    final remaining = rule.remainingCount == null
        ? null
        : rule.remainingCount! - 1;
    final active = remaining == null || remaining > 0;
    await _persist(
      rule.id,
      _advance(rule, rule.nextDue),
      remaining,
      active: active,
    );
  }

  /// Occurrences due within [days] of [now] across active rules, ascending.
  Future<List<UpcomingItem>> upcoming(DateTime now, {int days = 30}) async {
    final horizon = DateTime(now.year, now.month, now.day + days);
    final rules = await activeRules();
    final items = <UpcomingItem>[];
    for (final rule in rules) {
      var date = rule.nextDue;
      var guard = 0;
      while (!date.isAfter(horizon) && guard < 100) {
        if (rule.endDate != null && date.isAfter(rule.endDate!)) break;
        items.add(UpcomingItem(rule: rule, date: date));
        date = _advance(rule, date);
        guard++;
      }
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  DateTime _advance(RecurringRule rule, DateTime from) =>
      RecurringSchedule.next(
        from,
        frequency: rule.frequency,
        interval: rule.interval,
        anchorDay: rule.anchorDay,
      );

  Future<void> _post(RecurringRule rule, DateTime date) {
    return _tx.create(
      TransactionDraft(
        type: rule.type,
        amountMinor: rule.amountMinor,
        currency: rule.currency,
        accountId: rule.accountId,
        toAccountId: rule.toAccountId,
        categoryId: rule.categoryId,
        payee: rule.payee ?? rule.title,
        note: rule.note,
        date: date,
        recurringRuleId: rule.id,
      ),
    );
  }

  Future<void> _persist(
    int id,
    DateTime nextDue,
    int? remaining, {
    required bool active,
  }) {
    return (_db.update(
      _db.recurringRules,
    )..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        nextDue: Value(nextDue),
        remainingCount: Value(remaining),
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
