# ADR-0006: All period math through PeriodResolver

**Status**: accepted (2026-07-09)

## Context

Salaries in the target market often land on a fixed day (e.g., the 25th); a budget "month" that runs 1st–31st is wrong for those users. Scattered inline date math is where subtle period bugs breed (month ends, DST, year boundaries).

## Decision

A single `PeriodResolver(monthStartDay)` utility owns every conversion between dates and reporting periods. Budgets, reports, month switchers, and summaries all call it; **no feature code computes month ranges inline**. Calendar months are the `startDay = 1` special case. Day clamping (start day 29/30/31 in short months) is defined once, inside the resolver, and exhaustively unit-tested.

## Consequences

- Changing the month-start setting retroactively re-buckets all reporting — acceptable and correct (it's a view over transactions, not stored state).
- The resolver is TDD-first pure logic with the deepest edge-case suite in the app (see PLAN.md §9).
