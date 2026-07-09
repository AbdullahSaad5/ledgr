# ADR-0007: Ingestion via two build flavors; never READ_SMS on Play

**Status**: accepted (2026-07-09) — feature itself is v2 (PLAN.md §3.3); this records the distribution constraints now so nothing in v1 forecloses them.

## Context

v2 adds transaction ingestion: read SMS/notifications/emails as text, detect transaction-looking content, propose to the user (confirm-before-add, on-device parsing only). Constraints discovered up front:

- Google Play rejects finance apps requesting `READ_SMS` (restricted permission).
- Gmail API `gmail.readonly` is a restricted OAuth scope requiring verification + CASA security assessment — weeks-to-months of lead time; and CASA binds to the **OAuth client**, not to Play distribution, so sideloading alone doesn't avoid it.
- Plain **IMAP with a Google app-specific password** needs no OAuth client, no scopes, no CASA.

## Decision

Two product flavors sharing one codebase (parser, review queue, dedup identical):

- **`store`** (Play): `NotificationListenerService` ingestion only (covers bank apps, wallets, and SMS via the SMS app's notifications). Email only if/when CASA verification is completed. Never request `READ_SMS`.
- **`personal`** (sideloaded APK for Saad's devices): `READ_SMS` for full inbox parsing + Gmail via IMAP app-password (`enough_mail`), credentials in Keystore-backed secure storage, TLS only.

Candidates require explicit user confirmation before becoming transactions; raw message text never leaves the device.

## Consequences

- Flavor gating via Android `productFlavors` + Dart defines; source adapters are the only flavor-divergent code.
- Play Data Safety form and privacy policy must describe notification access honestly; the on-device-only story is the compliance defense.
- If email-on-Play is ever wanted, start the CASA process months ahead; ship notification ingestion first behind no flag dependency on it.
