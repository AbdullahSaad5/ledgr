import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/time/period_resolver.dart';

void main() {
  group('calendar months (startDay = 1)', () {
    final r = PeriodResolver(1);

    test('a mid-month date maps to that calendar month', () {
      final p = r.periodContaining(DateTime(2026, 1, 15));
      expect(p.start, DateTime(2026, 1, 1));
      expect(p.end, DateTime(2026, 2, 1));
      expect(p.anchorYear, 2026);
      expect(p.anchorMonth, 1);
    });

    test(
      'first of month is inclusive; last instant belongs to same period',
      () {
        final p = r.periodContaining(DateTime(2026, 3, 1));
        expect(p.start, DateTime(2026, 3, 1));
        expect(p.end, DateTime(2026, 4, 1));
        expect(r.contains(p, DateTime(2026, 3, 31, 23, 59)), isTrue);
        expect(r.contains(p, DateTime(2026, 4, 1)), isFalse);
      },
    );
  });

  group('salary month (startDay = 25)', () {
    final r = PeriodResolver(25);

    test('early-month date belongs to the period that started last month', () {
      final p = r.periodContaining(DateTime(2026, 7, 10));
      expect(p.start, DateTime(2026, 6, 25));
      expect(p.end, DateTime(2026, 7, 25));
      expect(p.anchorMonth, 6);
    });

    test('the start day itself opens a new period', () {
      final p = r.periodContaining(DateTime(2026, 7, 25));
      expect(p.start, DateTime(2026, 7, 25));
      expect(p.end, DateTime(2026, 8, 25));
      expect(p.anchorMonth, 7);
    });

    test('day before start day is still the previous period', () {
      final p = r.periodContaining(DateTime(2026, 7, 24));
      expect(p.start, DateTime(2026, 6, 25));
      expect(p.end, DateTime(2026, 7, 25));
    });
  });

  group('short-month clamping (startDay = 31)', () {
    final r = PeriodResolver(31);

    test('clamps to the last day of a short month', () {
      // Feb 2026 has 28 days -> start clamps to Feb 28.
      final p = r.periodContaining(DateTime(2026, 2, 15));
      expect(p.start, DateTime(2026, 1, 31));
      expect(p.end, DateTime(2026, 2, 28));
    });

    test('period starting in a clamped month runs to the next real 31st', () {
      final p = r.periodContaining(DateTime(2026, 3, 1));
      expect(p.start, DateTime(2026, 2, 28));
      expect(p.end, DateTime(2026, 3, 31));
    });
  });

  group('leap year (startDay = 30)', () {
    test('non-leap February clamps to 28', () {
      final r = PeriodResolver(30);
      final p = r.periodContaining(DateTime(2026, 2, 10));
      expect(p.start, DateTime(2026, 1, 30));
      expect(p.end, DateTime(2026, 2, 28));
    });

    test('leap February clamps to 29', () {
      final r = PeriodResolver(30);
      final p = r.periodContaining(DateTime(2028, 2, 10));
      expect(p.start, DateTime(2028, 1, 30));
      expect(p.end, DateTime(2028, 2, 29));
    });
  });

  group('navigation', () {
    final r = PeriodResolver(25);

    test('next rolls across a year boundary', () {
      final dec = r.ofAnchor(2026, 12);
      expect(dec.start, DateTime(2026, 12, 25));
      expect(dec.end, DateTime(2027, 1, 25));

      final jan = r.next(dec);
      expect(jan.start, DateTime(2027, 1, 25));
      expect(jan.end, DateTime(2027, 2, 25));
      expect(jan.anchorYear, 2027);
      expect(jan.anchorMonth, 1);
    });

    test('previous is the inverse of next', () {
      final p = r.ofAnchor(2026, 7);
      expect(r.previous(r.next(p)), p);
      expect(r.next(r.previous(p)), p);
    });

    test('ofAnchor matches periodContaining of its own start', () {
      final p = r.ofAnchor(2026, 9);
      expect(r.periodContaining(p.start), p);
    });
  });

  group('validation', () {
    test('rejects out-of-range start days', () {
      expect(() => PeriodResolver(0), throwsArgumentError);
      expect(() => PeriodResolver(32), throwsArgumentError);
    });

    test('accepts 1..31', () {
      expect(PeriodResolver(1).monthStartDay, 1);
      expect(PeriodResolver(31).monthStartDay, 31);
    });
  });
}
