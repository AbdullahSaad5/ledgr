# ADR-0001: Flutter, offline-first, and the locked stack

**Status**: accepted (2026-07-09)

## Context

Ledgr targets Android first but iOS later; the developer is solo; the product's trust story is privacy ("your financial data never leaves your phone").

## Decision

- **Flutter 3 / Dart 3** over native Kotlin — one codebase for future iOS/desktop; Material 3 support is first-class. Known cost: home-screen widgets need Kotlin glue.
- **Offline-first forever**: the local Drift (SQLite) database is the single source of truth for the UI in every version. Firebase (v2) is a sync layer on top, never a replacement. The app is fully functional signed-out; v1 ships with no network permission.
- Locked libraries: Riverpod 2 (codegen), Drift, go_router, freezed/json_serializable, fl_chart, local_auth, flutter_local_notifications, workmanager, decimal, shared_preferences.

## Consequences

- All state flows DB → Drift streams → Riverpod providers → widgets; writes only via repositories.
- No networking code, HTTP clients, or Firebase deps may enter v1.
- Substituting any locked library requires a superseding ADR.
