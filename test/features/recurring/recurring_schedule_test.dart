import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/recurring/domain/recurring_schedule.dart';

void main() {
  DateTime next(
    DateTime from, {
    required Frequency frequency,
    int interval = 1,
    int? anchorDay,
  }) => RecurringSchedule.next(
    from,
    frequency: frequency,
    interval: interval,
    anchorDay: anchorDay,
  );

  group('daily / weekly', () {
    test('daily adds interval days', () {
      expect(
        next(DateTime(2026, 7, 10), frequency: Frequency.daily),
        DateTime(2026, 7, 11),
      );
      expect(
        next(DateTime(2026, 7, 10), frequency: Frequency.daily, interval: 3),
        DateTime(2026, 7, 13),
      );
    });

    test('weekly adds 7×interval days across a month boundary', () {
      expect(
        next(DateTime(2026, 7, 28), frequency: Frequency.weekly),
        DateTime(2026, 8, 4),
      );
    });
  });

  group('monthly', () {
    test('simple next month', () {
      expect(
        next(DateTime(2026, 1, 15), frequency: Frequency.monthly),
        DateTime(2026, 2, 15),
      );
    });

    test('rolls across the year boundary', () {
      expect(
        next(DateTime(2026, 12, 10), frequency: Frequency.monthly),
        DateTime(2027, 1, 10),
      );
    });

    test('anchor day 31 clamps in short months but returns to 31', () {
      // Jan 31 -> Feb 28 (2026 non-leap), anchor kept at 31.
      final feb = next(
        DateTime(2026, 1, 31),
        frequency: Frequency.monthly,
        anchorDay: 31,
      );
      expect(feb, DateTime(2026, 2, 28));
      // Feb 28 -> Mar 31 (anchor restores the 31st).
      final mar = next(feb, frequency: Frequency.monthly, anchorDay: 31);
      expect(mar, DateTime(2026, 3, 31));
    });

    test('anchor day 31 into a leap February', () {
      expect(
        next(
          DateTime(2028, 1, 31),
          frequency: Frequency.monthly,
          anchorDay: 31,
        ),
        DateTime(2028, 2, 29),
      );
    });

    test('interval of 2 months', () {
      expect(
        next(DateTime(2026, 11, 15), frequency: Frequency.monthly, interval: 2),
        DateTime(2027, 1, 15),
      );
    });
  });

  group('yearly', () {
    test('Feb 29 anchor clamps to Feb 28 in a non-leap year', () {
      expect(
        next(DateTime(2028, 2, 29), frequency: Frequency.yearly, anchorDay: 29),
        DateTime(2029, 2, 28),
      );
    });

    test('normal yearly', () {
      expect(
        next(DateTime(2026, 6, 15), frequency: Frequency.yearly),
        DateTime(2027, 6, 15),
      );
    });
  });
}
