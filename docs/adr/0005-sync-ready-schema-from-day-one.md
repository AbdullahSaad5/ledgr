# ADR-0005: Sync-ready schema from day one

**Status**: accepted (2026-07-09)

## Context

Firebase sync (Google Sign-In, Firestore mirror) is confirmed for v2. Retrofitting stable ids and delete tracking onto a shipped local schema forces painful data migrations on real users.

## Decision

Every **syncable table** (`Accounts`, `Categories`, `Transactions`, `Tags`, `Budgets`, `RecurringRules`, `Debts`, `DebtPayments`, `Attachments`) carries from v1:

- `uuid TEXT UNIQUE` (client-generated v4) — the cross-device identity; Firestore doc id in v2.
- `updatedAt DATETIME` — touched on **every** write; repositories are responsible, no exceptions.
- `deletedAt DATETIME NULL` — tombstone. Syncable-table deletes set this instead of removing the row; all queries filter `deletedAt IS NULL`; a purge job removes tombstones older than 30 days. ("Delete with undo" UX = tombstone + un-tombstone.)

Local int ids remain the FK mechanism inside SQLite. Sync itself (outbox push, snapshot-listener pull, LWW on `updatedAt`, uuid-keyed merge) is v2 work — see PLAN.md §3.3.

## Consequences

- v2 sync becomes purely additive: no schema surgery, no user-data migration.
- Slight v1 cost: repositories must maintain `updatedAt`/tombstones, and tests assert it.
- Backup JSON includes uuids so restore-then-sync doesn't duplicate.
