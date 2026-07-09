import 'package:meta/meta.dart';

/// A single reporting period: a half-open range `[start, end)` at
/// local-midnight boundaries, named by the calendar month of its [start]
/// (see ADR-0006).
@immutable
class Period {
  const Period({
    required this.start,
    required this.end,
    required this.anchorYear,
    required this.anchorMonth,
  });

  /// Inclusive lower bound (local midnight).
  final DateTime start;

  /// Exclusive upper bound (local midnight) — the start of the next period.
  final DateTime end;

  /// Calendar year of [start].
  final int anchorYear;

  /// Calendar month of [start] (1..12).
  final int anchorMonth;

  @override
  bool operator ==(Object other) =>
      other is Period &&
      other.start == start &&
      other.end == end &&
      other.anchorYear == anchorYear &&
      other.anchorMonth == anchorMonth;

  @override
  int get hashCode => Object.hash(start, end, anchorYear, anchorMonth);

  @override
  String toString() => 'Period($start .. $end)';
}

/// Converts dates to reporting [Period]s given a user-configurable month start
/// day (ADR-0006). Every "month" in budgets and reports flows through here — no
/// feature code computes month ranges inline.
class PeriodResolver {
  PeriodResolver(this.monthStartDay) {
    if (monthStartDay < 1 || monthStartDay > 31) {
      throw ArgumentError.value(
        monthStartDay,
        'monthStartDay',
        'must be in 1..31',
      );
    }
  }

  /// Day of the calendar month on which a period opens (1..31); clamped down in
  /// months that are too short.
  final int monthStartDay;

  /// The period that contains [date].
  Period periodContaining(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final thisStart = _startIn(date.year, date.month);
    if (!day.isBefore(thisStart)) {
      final (ny, nm) = _nextMonth(date.year, date.month);
      return _period(thisStart, _startIn(ny, nm));
    }
    final (py, pm) = _previousMonth(date.year, date.month);
    return _period(_startIn(py, pm), thisStart);
  }

  /// The period whose start falls in calendar [year]/[month].
  Period ofAnchor(int year, int month) {
    final start = _startIn(year, month);
    final (ny, nm) = _nextMonth(year, month);
    return _period(start, _startIn(ny, nm));
  }

  Period next(Period p) {
    final (ny, nm) = _nextMonth(p.anchorYear, p.anchorMonth);
    return ofAnchor(ny, nm);
  }

  Period previous(Period p) {
    final (py, pm) = _previousMonth(p.anchorYear, p.anchorMonth);
    return ofAnchor(py, pm);
  }

  bool contains(Period p, DateTime instant) =>
      !instant.isBefore(p.start) && instant.isBefore(p.end);

  Period _period(DateTime start, DateTime end) => Period(
    start: start,
    end: end,
    anchorYear: start.year,
    anchorMonth: start.month,
  );

  /// The clamped start date within a given calendar month.
  DateTime _startIn(int year, int month) {
    final maxDay = _daysInMonth(year, month);
    final day = monthStartDay > maxDay ? maxDay : monthStartDay;
    return DateTime(year, month, day);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static (int, int) _nextMonth(int year, int month) =>
      month == 12 ? (year + 1, 1) : (year, month + 1);

  static (int, int) _previousMonth(int year, int month) =>
      month == 1 ? (year - 1, 12) : (year, month - 1);
}
