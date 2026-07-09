# ADR-0004: Transfers are a single row

**Status**: accepted (2026-07-09)

## Context

The classic double-entry approach (two mirrored rows) breeds bugs: orphaned halves on edit/delete, double counting in reports, sync races on the pair.

## Decision

A transfer is ONE `Transactions` row with `type = transfer`, `accountId` (source), `toAccountId` (target), and optional `feeMinor` charged to the source. Per-account sign is resolved in queries: source sees −amount (and −fee), target sees +amount.

Transfers (and adjustments, configurable) are **excluded** from income/expense reporting.

## Consequences

- Edit/delete is atomic by construction; no pairing invariants to maintain or repair.
- Every balance/report query must handle the transfer case explicitly — centralize the signed-amount CASE expression in one Drift view/DAO helper, never re-derive it ad hoc.
