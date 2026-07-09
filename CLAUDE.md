# CLAUDE.md — Ledgr

Personal finance & balance tracker. Flutter, Android-first, offline-first forever. **`PLAN.md` is the authoritative spec** — read the relevant section before building anything; this file is orientation + rules, not the spec.

## Current state

Pre-code. The repo contains the full plan, domain docs, and ADRs. Work is driven by the wayfinder map — issue [#1](https://github.com/AbdullahSaad5/ledgr/issues/1) — whose sub-issues #2–#13 chain the M0–M7 build (PLAN.md §10) plus open decisions. Claim the first open, unblocked, unassigned ticket; one ticket per session.

## What Ledgr is (30 seconds)

Every account (cash/bank/card/wallet) in one place; capture an expense in under 5 seconds via calculator keypad; budgets, reports, recurring transactions, debts (udhaar). 100% local Drift/SQLite in v1 — no backend, no network permission. v2 adds Firebase sync (Google Sign-In) and SMS/email transaction ingestion; v1 schema is already sync-ready (uuid/updatedAt/deletedAt on syncable tables). Details: PLAN.md §3.

## Stack (locked — do not substitute)

Flutter 3 / Dart 3, Material 3, Riverpod 2 codegen, Drift (SQLite), go_router, freezed + json_serializable, fl_chart, local_auth, flutter_local_notifications, workmanager. Rationale in `docs/adr/0001`.

## Non-negotiable engineering rules

1. **Money is integer minor units** (`amountMinor` int + currency). Never double/REAL for money. All arithmetic int; parse via `decimal`. ADR-0002.
2. **Balances are derived, never stored.** Computed from opening balance + transactions via SQL. ADR-0003.
3. **Transfers are one row** (accountId + toAccountId), sign resolved per-account in queries. ADR-0004.
4. **Sync-ready columns from day 1**: every syncable table gets `uuid`, `updatedAt` (touched on every write, repository's job), `deletedAt` tombstone (no hard deletes on syncable tables; queries filter `isNull`). ADR-0005.
5. **All period math through `PeriodResolver`** (custom month-start-day). Never inline month range math. ADR-0006.
6. **DB is the single source of truth.** UI reads Drift `.watch()` streams via Riverpod providers. Writes only through repositories. No DB access from widgets/notifiers.
7. Freezed immutability everywhere; no `setState` beyond trivial local widget state.
8. TDD for pure logic (Money, keypad evaluator, PeriodResolver, recurring `advance()` — these ship tests FIRST). 80% coverage gate.
9. No hardcoded colors/strings/values — theme tokens and constants. Both themes verified for every screen.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed/riverpod/drift codegen
flutter analyze                                            # must be clean before commit
flutter test --coverage
flutter run                                                # dev device/emulator
flutter build appbundle --release                          # store flavor
```

(Until M0 lands, `flutter create` per PLAN.md §10 M0 — org `com.saad`, project `ledgr`.)

## Repo layout

- `PLAN.md` — full product/tech spec (features §3, architecture §4, schema §5, screens §6, design §7, locked decisions §8, tests §9, milestones §10).
- `CONTEXT.md` — domain glossary; use its vocabulary in code, tests, and issues.
- `docs/adr/` — architectural decisions; flag conflicts, don't silently override.
- `docs/agents/` — issue tracker, triage labels, domain-doc consumer rules.
- `lib/` layout once code exists: feature-first, see PLAN.md §4 tree.

## Git

- Repo: `git@github.com:AbdullahSaad5/ledgr.git` (personal account, private). **Push over SSH only** (`git push origin main`, personal SSH key). For `gh` commands (issues, PRs, API), the default gh login is the work account which cannot see this repo — prefix with the personal token: `GH_TOKEN=$(gh auth token -u AbdullahSaad5) gh <cmd>`. Never `gh auth switch` (global, breaks other sessions). Details: `docs/agents/issue-tracker.md`.
- Conventional commits (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`...). No attribution footers.
- Branch per milestone/ticket; PRs optional while solo, required once collaborators exist.

## Agent skills

### Issue tracker

GitHub Issues on `AbdullahSaad5/ledgr`; external PRs are not a triage surface. See `docs/agents/issue-tracker.md` (includes wayfinder map/ticket conventions and the work-vs-personal `gh` auth caveat).

### Triage labels

Canonical five, unmodified (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

## Scope fence

v1 builds ONLY PLAN.md §3.1. Firebase, ingestion, multi-currency UI, widgets, SQLCipher are specced but fenced (§3.2/§3.3/§12). Do not start them early, do not "prepare abstractions" for them beyond the sync-ready columns.
