# CONTEXT.md — Ledgr domain glossary

Use these exact terms in code, tests, issues, and docs. Terms we deliberately avoid are listed at the bottom.

## Core money concepts

- **Money** — a value object: `{minor: int, currency: String}`. "Minor units" = the smallest currency unit (paisa, cents). All arithmetic happens on `minor`. There is no floating-point money anywhere in the system.
- **Home currency** — the single currency the user selects at onboarding (default PKR). In v1 every row is in home currency; the column exists for v2 multi-currency.
- **Account** — a place money sits: cash, bank, credit card, mobile wallet, savings, investment, other. Has an **opening balance**.
- **Balance** — always **derived**: `opening balance + Σ signed transactions`. Never stored, never cached in DB. If you find yourself wanting to store one, read ADR-0003.
- **Net worth** — Σ balances of accounts with `includeInNetWorth = true`.

## Transactions

- **Transaction** — one money event. Exactly one of four **types**:
  - **Expense** — money out of an account, has a category.
  - **Income** — money into an account, has a category.
  - **Transfer** — between two own accounts; ONE row (`accountId` → `toAccountId`), optional **fee** charged to the source account. Excluded from income/expense reports.
  - **Adjustment** — created by **Reconcile** to make a derived balance match reality. Not user-categorized.
- **Amounts are stored positive**; `type` decides the sign. Signed values are computed in SQL, one convention everywhere.
- **Payee** — the merchant/person on a transaction. Autocompleted from history.
- **Reconcile** — user enters the real-world balance of an account; the app posts an Adjustment for the difference.
- **Duplicate** (verb, UI action) — create a new transaction copying an existing one, dated now.

## Time

- **Period** — a reporting month whose start day is user-configurable (e.g., salary on the 25th → "July" = Jun 25–Jul 24). ALL month math flows through **PeriodResolver**. "Calendar month" is the special case `startDay = 1`.

## Budgeting & recurrence

- **Budget** — a monthly spending limit for one category (or **overall** when categoryId is null). Progress = period spend / limit.
- **Recurring rule** — a template transaction + schedule. Two modes: **auto-post** (creates the transaction when due) and **remind-only** (notification with an "Add now" action). The engine's **catch-up** posts anything that came due while the app was closed, exactly once (idempotent via `nextDue` advancement).
- **Upcoming** — the next 30 days of expected rule instances, with **mark-paid** and **skip** actions.

## Debts

- **Debt** (colloquially *udhaar*) — money lent to (**lent**) or borrowed from (**borrowed**) a person. Has principal, optional due date, and **payments** (partial repayments, each optionally posting a real transaction). **Settled** when remaining = 0 or user closes it.

## Sync & data lifecycle (v1 groundwork, v2 feature)

- **Syncable table** — a table carrying `uuid` / `updatedAt` / `deletedAt`.
- **Tombstone** — a row with `deletedAt` set. Deletes on syncable tables are tombstones, not row removal; a purge job clears tombstones older than 30 days. Queries always filter `deletedAt IS NULL`.
- **Outbox** (v2) — queue of pending local writes to push to Firestore.
- **Archive** (accounts/categories) — hidden from pickers, history preserved. Distinct from delete/tombstone.

## Ingestion (v2)

- **Candidate** — a transaction-looking parse of a message/notification/email, awaiting user decision. Never becomes a Transaction without explicit confirmation.
- **Sender** — a whitelisted source (bank SMS shortcode, app package, email address) with its parsing templates.
- **Fingerprint** — dedup key: amount + direction + account hint + time bucket + normalized merchant.
- **Flavors** — `store` (Play-compliant: notification listener only) vs `personal` (sideloaded: READ_SMS + IMAP email).

## Terms we avoid

- ~~"wallet"~~ for the app itself (a Wallet is an *account type*); the app is a *tracker*.
- ~~"entry"/"record"~~ → say **transaction**.
- ~~"category budget" vs "total budget"~~ → **budget** (category) vs **overall budget**.
- ~~"subscription"~~ → **recurring rule** (subscriptions are just one use).
- ~~"loan"~~ → **debt** (direction: lent/borrowed).
- ~~"month"~~ in code when you mean **period**.
