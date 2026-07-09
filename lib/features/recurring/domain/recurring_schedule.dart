import 'package:ledgr/core/db/enums.dart';

/// Computes the next due date of a recurring rule (PLAN.md §4). Pure logic so
/// the highest-risk part of the app — date advancement across month ends and
/// leap years — is exhaustively unit-tested.
abstract final class RecurringSchedule {
  /// The due date strictly after [from], given the cadence. [anchorDay] is the
  /// rule's intended day-of-month (so a rule anchored on the 31st returns to 31
  /// in long months rather than drifting after a short one); when null, the
  /// day of [from] is used.
  static DateTime next(
    DateTime from, {
    required Frequency frequency,
    int interval = 1,
    int? anchorDay,
  }) {
    assert(interval >= 1, 'interval must be >= 1');
    switch (frequency) {
      case Frequency.daily:
        return _atMidnight(from).add(Duration(days: interval));
      case Frequency.weekly:
        return _atMidnight(from).add(Duration(days: 7 * interval));
      case Frequency.monthly:
        return _addMonths(from, interval, anchorDay);
      case Frequency.yearly:
        return _addMonths(from, 12 * interval, anchorDay);
    }
  }

  static DateTime _addMonths(DateTime from, int months, int? anchorDay) {
    final total = (from.year * 12 + (from.month - 1)) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final desired = anchorDay ?? from.day;
    final day = desired > _daysInMonth(year, month)
        ? _daysInMonth(year, month)
        : desired;
    return DateTime(year, month, day);
  }

  static DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
