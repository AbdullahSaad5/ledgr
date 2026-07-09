# ADR-0002: Money is integer minor units

**Status**: accepted (2026-07-09)

## Context

Floating-point money produces rounding drift (0.1 + 0.2 ≠ 0.3); a finance app whose totals are off by a paisa loses all trust.

## Decision

Money is an immutable value type `{int minor, String currency}` with value equality. Implementation note (amended 2026-07-09, M0): `Money` is a hand-written `const` class with manual `==`/`hashCode`, not a freezed class — it carries substantial behavior (arithmetic operators, parsing, formatting) and staying codegen-free keeps its test loop instant (`flutter test` with no build_runner step). The ADR's substance — integer minor units, value semantics — is unchanged. DB columns are `amountMinor INTEGER` + `currency TEXT` — **no REAL column ever holds money**. Parsing user input goes through the `decimal` package → minor units. Formatting via `intl` NumberFormat with the currency's digit count. Division (splits, averages) rounds half-even, documented at the call site.

Amounts are stored **positive**; the transaction `type` determines sign. Signed values are computed in SQL (`CASE WHEN type = expense THEN -amountMinor …`) — one convention, used by every query.

## Consequences

- The keypad expression evaluator computes on Decimal and converts to minor exactly once, at save.
- Any aggregate (budgets, reports, balances) sums integers; equality is exact; tests assert exact values.
- Multi-currency (v2) needs no schema change — `currency` rides on every money row from day 1.
