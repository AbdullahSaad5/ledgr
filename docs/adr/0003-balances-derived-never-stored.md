# ADR-0003: Balances are derived, never stored

**Status**: accepted (2026-07-09)

## Context

Storing a running balance per account invites drift bugs: every insert/edit/delete/transfer path must update it correctly, forever, including sync merges later.

## Decision

`balance(account) = openingBalanceMinor + Σ signed transactions touching that account`, computed by an indexed SQL aggregate, exposed as a reactive Drift watch query. No balance column exists anywhere.

Real-world drift (cash lost, forgotten expenses) is handled by the **Reconcile** feature: user enters the actual balance, app posts an **Adjustment** transaction for the difference.

## Consequences

- Balance correctness is a pure function of transaction rows — one well-tested query instead of N write paths.
- v2 sync merges can't corrupt balances; merged rows re-derive automatically.
- Perf: `Transactions(accountId, date)` index; thousands of rows aggregate in microseconds. If a table ever gets huge, add `NetWorthSnapshots` as a *cache* (supersede via new ADR), never as the source of truth.
