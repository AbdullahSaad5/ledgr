# Ledgr — Personal Finance & Balance Tracker: Full Implementation Plan

> Working title: **Ledgr** (alternatives: Paisa Track, Khaata, BalanceBook — decide before Play listing; note "Paisa" already used by an OSS Flutter app, check name collision).
> Platform: **Flutter** (Android first, iOS later). This document is the complete spec: hand it to the coding agent and build top to bottom.

---

## 1. Product Vision

A private, offline-first money manager: every account (cash, bank, cards, wallets) in one place, every expense captured in under 5 seconds, and honest answers to "where did my money go" and "what am I worth right now".

Core loops:
1. **Capture**: FAB → amount on a calculator keypad → category → done. Speed is the product.
2. **Awareness**: home shows net worth + this month's spend vs budget at a glance.
3. **Review**: monthly reports (category pie, trends, cashflow) that actually load instantly because everything is local SQL.

Differentiators: truly offline + private (no account, no analytics on financial data), transfer-aware balances that always reconcile, debt/udhaar tracking (owed to me / by me — big in the Pakistani market), clean Material 3 UI. No ads in v1; Pro unlock later.

---

## 2. Tech Stack (locked — shared with CartList where possible)

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter 3.x, Dart 3, Material 3 | |
| State | Riverpod 2 (codegen) | same patterns as CartList |
| DB | Drift (SQLite) | heavy aggregate queries — SQL is the right tool here |
| Navigation | go_router | |
| Models | freezed + json_serializable | |
| Charts | fl_chart | pie, bar, line |
| Money math | **integer minor units** (`amountMinor` int) + `decimal` package for parsing | NEVER double for money |
| Local auth | local_auth (biometric) + PIN fallback (hashed via `crypto`) | |
| Notifications | flutter_local_notifications | bill reminders, recurring posted |
| Background work | workmanager | recurring transaction engine safety net |
| Files | file_picker + share_plus + SAF | CSV/JSON export, backup |
| Receipt photos | image_picker, stored in app support dir | |
| Prefs | shared_preferences | non-sensitive settings only |

**No backend, no cloud in v1.** Backup = local file export (+ "save to Drive" via system share/SAF, not Drive API). Drive API auto-backup is v1.1.

---

## 3. Feature Set

### 3.1 MVP (v1.0)

**Accounts**
- Types: Cash, Bank, Credit Card, Mobile Wallet (JazzCash/Easypaisa/etc.), Savings, Investment (manual value), Other.
- Fields: name, type, icon, color, opening balance, currency (single home currency in MVP — see §8), include-in-net-worth toggle, archived flag.
- Balance = opening balance + Σ signed transactions (computed, never stored — single source of truth; cached in memory via watch queries).
- Credit cards: balance shown as negative naturally; optional credit limit field → utilization bar.
- Account detail screen: balance header, filterable transaction history, edit/archive.
- Reorder accounts; archived hidden from pickers but history preserved.
- **Reconcile**: enter "actual balance now" → app computes difference → offers to create an adjustment transaction (category: Balance Adjustment).

**Transactions**
- Types: **expense**, **income**, **transfer** (between own accounts — creates one row with fromAccount+toAccount; excluded from income/expense reports; fee field optional → posts a linked expense).
- Fields: amount, type, account (from/to for transfer), category, subcategory (optional), date+time, payee/merchant (autocomplete from history), note, tags (multi), receipt photo(s), recurring link (if spawned by a rule).
- **Add flow (the 5-second path)**: FAB → full-screen add: big amount display + custom calculator keypad (supports + − × ÷ so "1200+350=" works) → type toggle (expense/income/transfer segmented) → account chip (defaults to last used) → category grid (icons, most-used first) → Save. Date defaults now; everything else optional behind "More".
- Edit = same screen prefilled. Delete with undo snackbar.
- Duplicate transaction action ("same as last time").
- Search: by payee/note/amount/category/tag; full filter sheet: date range, accounts, categories, type, amount range, tags.
- Transaction list grouping: by day with day-header showing daily net; sticky month headers with month totals.

**Categories**
- Two trees: expense categories & income categories. Defaults seeded (~18 expense: Food & Dining, Groceries, Transport, Fuel, Bills & Utilities, Rent, Shopping, Health, Education, Entertainment, Subscriptions, Travel, Family, Charity/Zakat, Fees, Personal Care, Gifts, Other; ~7 income: Salary, Business, Freelance, Gifts, Interest/Profit, Refunds, Other).
- One level of subcategories (e.g., Bills → Electricity/Internet/Phone). CRUD, icon+color picker, reorder, merge-on-delete (deleting a category prompts "move n transactions to …").

**Budgets**
- Monthly budget per category (or overall). Amount + optional rollover toggle (unused carries to next month — computed, MVP can defer rollover to v1.1 if hairy).
- Budgets screen: month selector, each budget row = category, spent/limit, progress bar (green→amber 80%→red 100%), remaining. Overall header: total budgeted vs spent.
- Home surfaces top 3 budgets nearest to limit.
- Notification when a budget crosses 80% and 100% (checked on each transaction insert — no polling).

**Recurring transactions & bill reminders**
- Rule: template transaction + schedule (daily/weekly/monthly/yearly, interval, day-of-month with clamping, end date or count, optional).
- Modes per rule: **auto-post** (transaction created on due date, notification "Posted: Rent Rs 50,000") or **remind-only** (notification with "Add now" action → prefilled add screen).
- Engine: on every app open, catch-up-post anything due while app closed (idempotent: rule stores lastPostedPeriod); workmanager daily job as safety net for notifications.
- Upcoming screen: next 30 days of expected recurrings + bills, with mark-paid/skip actions.

**Debts (udhaar) — owed to me / owed by me**
- Debt record: person name, direction (I lent / I borrowed), principal, account it moved through (optional — if set, posts the initial transaction), due date (optional), note.
- Partial repayments: child entries against a debt, each optionally posting a real transaction. Debt shows remaining, history, settled state.
- Debts screen: two tabs (Owed to me / I owe), totals on top, overdue highlighted.

**Reports**
- Month view (default, swipe between months): income, expense, net; expense pie/donut by category (tap slice → drilldown to subcategory then transaction list); top payees.
- Trends: 6/12-month bar chart income vs expense; per-category line trend.
- Cashflow: running balance line for selected account(s) over range.
- Net worth: current = Σ included account balances; history chart from daily snapshots (see §8) — MVP can compute retroactively from transactions.
- All reports respect a global filter (accounts included).
- Export current report view as CSV.

**Security & privacy**
- App lock: PIN (4–6 digit, salted SHA-256 in secure storage) + biometric unlock; lock on launch + after n minutes background (setting). Privacy screen (blank/blur) in recents.
- No network permission needed in v1 — a selling point; state it in the listing.

**Data**
- Full backup export/import: single JSON (versioned) via share/SAF. CSV export of transactions (per filter).
- CSV import (v1 if cheap: map columns → preview → import; else v1.1).

**Settings**
- Theme (system/light/dark, dynamic color, accent seeds), home currency + symbol + decimal digits, first day of week/month (salary-cycle month start day! e.g., month starts on 25th), app lock config, notifications toggles, categories manage, data (backup/import/export/clear), about.

**Polish (MVP-mandatory)**
- Material 3, dynamic color, tonal surfaces; hero number typography for balances (large, tabular figures).
- Amount colors: expense red-tinted, income green-tinted, transfer neutral — with icons too (not color-only, accessibility).
- Animations: FAB → add screen container transform; count-up animation on balance changes; chart entrance animations; list insertions animated.
- Haptics on keypad and save. Empty states everywhere. Undo for deletes. Onboarding: welcome → set currency → create first accounts (cash + bank prefilled suggestions) → optional starting balances → done.

### 3.2 v1.1

- Google Drive auto-backup (drive.appdata scope), scheduled.
- Home-screen widgets: balance summary; quick-add expense shortcut.
- Rollover budgets, weekly/custom-period budgets.
- CSV import with column mapping (if deferred), import presets for common bank formats.
- Multi-currency accounts with manual/API rates (see §8 — schema ready from day 1).
- Tags screen + tag reports. Receipt gallery view.
- Urdu localization (ARB infra done in MVP).

### 3.3 v2 — Firebase era (planned now, built later)

Decision locked: Firebase + Google Sign-In sync IS coming, but **offline-first is the architecture forever** — Firebase is a sync/backup layer over the local Drift DB, never a replacement. App fully functional signed-out; sign-in always optional (soft prompt in Settings + one-time "back up your data?" card, never a wall).

**v2.0 — Auth + multi-device sync**
- Firebase Auth: Google Sign-In primary; anonymous auth linked/upgraded on sign-in so pre-login data survives.
- Firestore mirror under `users/{uid}/`: accounts, transactions, categories, budgets, recurringRules, debts (+payments), tags — one collection each, keyed by row `uuid`. Attachments (receipt photos) → Firebase Storage `users/{uid}/receipts/{uuid}` (upload wifi-only setting).
- Sync engine identical pattern to CartList: Drift = single source of truth for UI; outbox pattern pushes local writes; snapshot listeners pull remote upserts by `uuid` where remote `updatedAt` newer; tombstones (`deletedAt`) for deletes, 30-day purge.
- Conflict rule: last-write-wins per row on `updatedAt` (server timestamp). Financial caveat: transactions are near-append-only in practice, so LWW collisions are rare; balances stay correct automatically because they're derived, never stored (§8.2 pays off here).
- First sign-in: bulk upload local DB; existing cloud data merges by uuid. Sign-out keeps local data, stops sync.
- **Privacy stance update**: v1 "no network permission" claim dies in v2 — listing and privacy policy updated honestly; analytics/crashlytics only behind consent toggle; financial rows never sent anywhere except the user's own Firestore.
- Security rules: `users/{uid}/**` readable/writable only by that uid; rules tested with emulator.

**v2.x — Transaction ingestion from messages & email (decision locked: this ships, own phase)**

The app can, with explicit opt-in, read the *text* of the user's bank SMS/notifications and emails, detect transaction-looking content, and propose it to the user. **Never auto-adds** — every candidate requires user confirmation. All parsing on-device; raw message text never leaves the phone and is never uploaded (not even to the user's own Firestore — only confirmed transactions sync).

- **Sources, in build order:**
  1. **Notification listener** (Android `NotificationListenerService` via method channel): reads bank/wallet app + SMS-app notifications as they arrive. This is the Play-safe route — `READ_SMS` is a restricted permission Google rejects expense trackers for, notification access is not. Covers JazzCash/Easypaisa/bank apps AND incoming SMS (since the SMS app posts notifications). User grants notification access via system settings screen (in-app explainer first).
  2. **Email — Gmail API** (`gmail.readonly`, user's Google account from the v2.0 sign-in): background periodic fetch of last N days from known bank senders. ⚠️ Restricted scope: requires Google OAuth verification + CASA security assessment before public release — budget real lead time; feature-flag it and ship notification ingestion first. Fallback/interim: manual "paste email text" import box using the same parser.
- **Parser (on-device, deterministic first):**
  - Sender/package whitelist (user-editable, seeded with PK banks + wallets; "unknown sender looked like a transaction" still surfaces with a lower-confidence badge).
  - Extraction: amount + currency, direction (debit/credit keyword sets), merchant/payee, date, account hint (last-4 digits matched against a per-account "card/account numbers" field users can optionally fill).
  - Template-per-sender regex library, versioned and unit-tested against a fixtures corpus of real (sanitized) messages. Unmatched-but-plausible messages parsed by a generic amount+keyword heuristic.
  - Later option (flagged, off by default): small on-device model or LLM API for gnarly formats — only with explicit consent because API = text leaves device.
- **Review queue UX:** "Detected" inbox (badge on Transactions tab): card per candidate showing parsed fields + source snippet, actions [Add] (one tap, applies guesses) / [Edit & add] (prefilled add screen) / [Dismiss] / [Dismiss & mute sender]. Notification "New transaction detected: Rs 4,500 HBL — add?" with Add/Dismiss actions. Learns: confirming a merchant→category mapping remembers it.
- **Dedup (phase 2 of this feature — later, per decision):**
  - Cross-source: same transaction arriving via SMS notification AND email → fingerprint = amount + direction + account-hint + timestamp bucket (±36h) + normalized merchant; candidates matching an existing fingerprint auto-merge into one card (sources listed on it).
  - Against manual entries: if user already added it by hand, candidate shows "possible duplicate of …" and defaults to Dismiss.
  - Recurring-rule aware: candidate matching a due recurring rule offers "mark rule instance as paid" instead of creating a second transaction.
- **Schema (added in this phase, normal Drift migration):** `TransactionCandidates(id, uuid, source enum sms/notification/email/manual-paste, senderId, rawTextEncrypted, parsedAmountMinor, parsedDirection, parsedMerchant, parsedDate, accountGuessId, confidence, fingerprint, status enum pending/added/dismissed, linkedTransactionId, createdAt)` + `IngestSenders(id, name, packageOrAddress, type, muted, templateVersion)`. Confirmed candidates set `linkedTransactionId`; raw text purged after 90 days or on dismiss.
- **Privacy copy & Play compliance:** dedicated consent screen before enabling (what is read, what is stored, nothing uploaded); Data Safety form updated; notification-access apps get extra Play review — the on-device-only story is the defense. Gmail scope gets its own consent, separate from sign-in.
- **Distribution strategy — two build flavors:**
  - `store` (Play): notification-listener ingestion; email only if/when CASA verification done; never `READ_SMS`.
  - `personal` (sideloaded APK, Saad's own devices): Play policy doesn't apply → may include `READ_SMS` for direct SMS-inbox parsing, and email via **Gmail IMAP + app-specific password** (`enough_mail` package) — plain IMAP needs no OAuth client, no scopes, no CASA at all. Credentials in Android Keystore-backed secure storage, TLS only.
  - Important: CASA is attached to the **Gmail API OAuth client**, not to Play — sideloading alone doesn't dodge it. The dodge for personal use is either IMAP (recommended, no expiry pain) or leaving the OAuth consent screen in Testing mode (works for ≤100 test users but refresh tokens expire every 7 days → weekly re-login, annoying).
  - Same codebase, flavor-gated via Dart defines + Android productFlavors; parser/queue/dedup identical across flavors.

**v2.x — rest**
- Shared/household wallets (needs member model like CartList shared lists — separate spec).
- Pro IAP: widgets+, unlimited budgets/rules, sync, ingestion(?), icon packs.

**Cost/ops**: Spark tier fine early; no Cloud Functions needed for v2.0 (client-driven sync); Storage costs watched (receipt photos are the only heavy object).

---

## 4. Architecture

Same rules as CartList (see its §4): feature-first, Riverpod-only state, repositories over Drift DAOs, DB is single source of truth, freezed immutability, no business logic in widgets.

```
lib/
  main.dart
  app/ (router, theme, l10n, lock_gate.dart — wraps router with app-lock)
  core/
    db/ (database, tables, seed, converters: MoneyConverter, enum converters)
    money/ (Money value type: int minor units + currency; formatting; keypad expression evaluator)
    utils/ (date ranges w/ custom month-start, notifications service, haptics)
    widgets/ (AmountText, CategoryIcon, EmptyState, ProgressBudgetBar, MonthSwitcher,
              CalcKeypad, IconPickerSheet, ColorPickerRow, ConfirmSheet)
  features/
    home/            # dashboard
    accounts/        # list, detail, edit, reconcile
    transactions/    # add/edit screen, list, search+filters, detail sheet
    categories/
    budgets/
    recurring/       # rules CRUD, engine, upcoming screen
    debts/
    reports/
    security/        # pin setup, lock screen, biometric
    backup/          # export/import JSON, CSV
    settings/
    onboarding/
```

**Money rules for the coding agent (non-negotiable):**
- `Money` freezed type: `{int minor, String currency}`. All arithmetic in int. Parsing user input via `decimal` → minor units. Formatting via `intl` NumberFormat with currency digits.
- DB stores `amountMinor INTEGER` + `currency TEXT`. No REAL columns for money anywhere.
- Signs: store all amounts positive + `type` column decides sign; signed views computed in queries (`CASE WHEN type=expense THEN -amount ...`). One convention, documented in code, used everywhere.

**Recurring engine correctness:** rule has `nextDueLocalDate`; posting loop: `while (nextDue <= today) { postIfAutoElseNotify(); nextDue = advance(nextDue); }` in one transaction per rule; `advance` handles month-end clamp (Jan 31 → Feb 28) by keeping original anchor day. Unit-test this hard (DST, month ends, yearly Feb 29).

---

## 5. Data Model (Drift schema v1)

```dart
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<AccountType>()();            // cash/bank/creditCard/wallet/savings/investment/other
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();                       // ISO 4217; MVP: all = home currency
  IntColumn get creditLimitMinor => integer().nullable()();
  BoolColumn get includeInNetWorth => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get kind => intEnum<CategoryKind>()();           // expense / income
  IntColumn get parentId => integer().nullable().references(Categories, #id)();  // one level deep
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get position => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => intEnum<TxType>()();                 // expense / income / transfer / adjustment
  IntColumn get amountMinor => integer()();                  // always positive
  TextColumn get currency => text()();
  IntColumn get accountId => integer().references(Accounts, #id)();          // source (expense/transfer-from)
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)(); // transfer target
  IntColumn get feeMinor => integer().nullable()();          // transfer fee, posts against accountId
  IntColumn get categoryId => integer().nullable().references(Categories, #id)(); // null for transfers
  TextColumn get payee => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();                   // user-set, drives all reports
  IntColumn get recurringRuleId => integer().nullable().references(RecurringRules, #id, onDelete: KeyAction.setNull)();
  IntColumn get debtId => integer().nullable().references(Debts, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime()();
}

class TransactionTags extends Table {                        // + Tags(id, name unique, color)
  IntColumn get transactionId => integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override Set<Column> get primaryKey => {transactionId, tagId};
}

class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();                           // relative to app support dir
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.cascade)(); // null = overall
  IntColumn get limitMinor => integer()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  // template fields: type, amountMinor, currency, accountId, toAccountId, categoryId, payee, note
  IntColumn get frequency => intEnum<Frequency>()();         // daily/weekly/monthly/yearly
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get anchorDay => integer().nullable()();         // day-of-month anchor for clamping
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get remainingCount => integer().nullable()();
  BoolColumn get autoPost => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get title => text()();                          // "Rent", "Netflix"
}

class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text()();
  IntColumn get direction => intEnum<DebtDirection>()();     // lent / borrowed
  IntColumn get principalMinor => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  // repayments are Transactions with debtId set + a DebtEntries view, or a small DebtPayments table:
}

class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get date => dateTime()();
  IntColumn get transactionId => integer().nullable().references(Transactions, #id, onDelete: KeyAction.setNull)();
}
```

Indexes: `Transactions(date)`, `Transactions(accountId, date)`, `Transactions(categoryId, date)`, `Transactions(payee)`, `RecurringRules(nextDue, active)`.

**Sync-readiness (build into v1 schema NOW — Firebase sync coming in v2, §3.3).** Every syncable table (`Accounts`, `Categories`, `Transactions`, `Tags`, `Budgets`, `RecurringRules`, `Debts`, `DebtPayments`, `Attachments`) also gets:

```dart
TextColumn get uuid => text().clientDefault(() => const Uuid().v4()).unique()();  // stable cross-device id
DateTimeColumn get updatedAt => dateTime()();       // touched on EVERY write (repository responsibility)
DateTimeColumn get deletedAt => dateTime().nullable()();  // tombstone; all queries filter isNull
```

v1 behavior: int ids stay the local FK mechanism; syncable-table deletes become tombstones (30-day purge job) — note transactions' "hard-delete with undo" (§8.7) becomes tombstone+undo, same UX; `updatedAt` maintained by repositories from day 1; backup JSON carries uuids. Result: v2 sync is purely additive, zero migration for existing users.

**Core queries (write as Drift views/DAO methods, all reactive `.watch()`):**
- `accountBalance(id)`: opening + Σ(income to it) − Σ(expense/fee from it) − Σ(transfer out) + Σ(transfer in) ± adjustments.
- `monthSummary(range)`: totals by type excluding transfers/adjustments (adjustments configurable in settings).
- `spendByCategory(range)`: with parent rollup (subcategory sums into parent for the pie, drilldown splits).
- `budgetProgress(month)`: join budgets × spend.
- Month ranges derive from **custom month-start-day** setting — one utility (`PeriodResolver`) used by every report/budget query; never inline date math.

**Backup JSON**: versioned envelope with all tables + attachment files zipped alongside (v1: JSON only, note that photos aren't in backup; v1.1: zip).

---

## 6. Screen-by-Screen Spec

### 6.1 Shell
Bottom `NavigationBar` (M3): **Home · Transactions · [＋ FAB notched/center-docked] · Budgets · Reports**. Accounts, Debts, Recurring, Settings reachable from Home and drawer-less overflow. FAB always = new transaction.

### 6.2 Home / Dashboard — `/`
- Header: "Net worth" hero amount (count-up animation, tap to hide/blur — privacy glance mode), delta vs last month chip.
- Accounts carousel: horizontally scrollable account cards (color, icon, name, balance; credit card shows utilization bar). Last card = "+ Add account". Tap → account detail. "See all" → accounts screen (reorder/archive there).
- "This month" card: income / expense / net, thin sparkline of daily spend.
- Budgets snapshot: top 3 budgets by % used, mini progress bars → Budgets tab.
- Upcoming: next 5 recurring/bills with due chips → Upcoming screen.
- Recent transactions (last 5) → Transactions tab.

### 6.3 Add/Edit transaction — `/tx/new`, `/tx/:id/edit` (full-screen, container transform from FAB)
- Top: segmented Expense | Income | Transfer.
- Amount zone: giant amount text (auto-scaling), currency symbol, live expression preview ("1200+350").
- `CalcKeypad`: 0-9, decimal, ⌫, + − × ÷, =, oversized Save. Operators chain; Save evaluates first.
- Chips row: account (sheet picker), date (defaults today; chips: Today/Yesterday/pick), category button opens grid sheet (most-used first, search, subcategory drill).
- Transfer mode: from-account, to-account, optional fee field; category hidden.
- "More" expands: payee (autocomplete top 5 from history — selecting payee also suggests its most-common category), note, tags (chips + create inline), receipt photo thumbnails (camera/gallery), mark as recurring… (jumps to rule creation prefilled).
- Save → haptic + pop; if from FAB, snackbar "Saved · Undo".

### 6.4 Transactions — `/transactions`
- Month switcher row (‹ July 2026 ›, swipe anywhere on list also switches), month net summary strip.
- Day-grouped list: day header (date + weekday + day net), rows: category icon in tinted circle, payee/category title, account + note subtitle, amount right-aligned colored + typed icon. Transfer rows show from→to.
- Tap row → detail bottom sheet (all fields, map of actions: edit, duplicate, delete-undo, view receipt full-screen).
- Search icon → search screen with filter sheet (accounts, categories multi-select, type, date range, amount range, tags). Active filters shown as dismissible chips. Filtered totals shown ("42 transactions · Rs 84,300").
- Multi-select (long-press): delete, re-categorize, add tag.

### 6.5 Accounts — `/accounts`, detail `/accounts/:id`
- List grouped by type, balances + group subtotals, net worth footer. Reorder, add.
- Detail: hero balance, [Edit] [Reconcile] buttons, filter chips (month), transaction list scoped to account, cashflow mini-chart.
- Edit sheet: all fields; archive (confirm explains history preserved); delete only if zero transactions, else offer archive.
- Reconcile sheet: "Actual balance?" → shows computed difference → [Create adjustment] / cancel.

### 6.6 Budgets — `/budgets`
- Month switcher. Overall card (budgeted / spent / left, big progress). Budget rows with progress bars + spent/limit/remaining; tap → category drilldown (transactions this month). Add-budget flow: pick category → amount keypad. Edit/delete via row overflow.

### 6.7 Reports — `/reports` (tabs: Overview · Categories · Trends · Net worth)
- Overview: month switcher, income/expense/net cards, donut by category (legend list with amounts+%, tap → drilldown), top 5 payees.
- Categories: pick category → monthly bar trend + transaction list.
- Trends: 12-month grouped bars income vs expense; average line; tap month → jumps to that month's overview.
- Net worth: line chart over time + per-account breakdown table.
- Every chart: entrance animation, empty state, and an export-CSV action for underlying data. Follow dataviz skill guidance when building charts.

### 6.8 Debts — `/debts`
Two tabs Owed to me / I owe, totals header, cards (person, remaining/principal progress, due date badge, overdue = error tint). Detail: payment history, [Add payment] (optionally posts transaction to chosen account), [Settle]. New debt flow mirrors transaction add (keypad).

### 6.9 Recurring & Upcoming — `/recurring`, `/upcoming`
- Rules list: title, template summary, next due, auto/remind badge, active toggle. CRUD full screen.
- Upcoming: next 30 days timeline; each entry [Mark paid → posts now] [Skip this one] [Open rule].

### 6.10 Security — lock screen (blocks router via redirect), PIN setup in settings, biometric prompt on resume.

### 6.11 Settings, Onboarding, Backup — as in §3. Onboarding sets currency (searchable ISO list, default PKR), creates suggested accounts with opening balances.

---

## 7. Design System

- **Color**: dynamic color default; fallback seed deep teal `#00696D`. Semantic pair: income green / expense red — derive from M3 palette but fix hues (`tertiary` for income, `error`-adjacent for expense), verify both themes, never color-only (always paired icon: ↓ in / ↑ out / ⇄ transfer).
- **Numbers**: tabular figures (`FontFeature.tabularFigures()`) on every amount; hero balances use large display type (e.g., "Sora" or default display-large). Amount text auto-shrinks, never wraps.
- **Cards & layout**: M3 tonal cards, 16dp radius; dashboard is a `CustomScrollView` of slivers; generous whitespace, one accent per card max.
- **Charts**: fl_chart styled to theme (no library default colors); category colors come from the category entity so pie == list == icons everywhere; rounded bar caps; animated on first build only.
- **Motion**: FAB container-transform to add screen; count-up on balances (300ms, ease-out); sheet transitions default M3; list item add/remove animated.
- **Privacy affordance**: eye icon toggles amount blur everywhere (single provider).
- **Accessibility**: semantics on amounts ("expense, 1,200 rupees, Groceries"), 48dp targets, large-font audit, contrast on progress-bar states.

---

## 8. Hard Problems — decisions locked now

1. **Money as integers.** §4 rules. The keypad expression evaluator works on Decimal, converts to minor at save. Division rounds half-even, documented.
2. **Balances are derived, never stored.** No drift between stored and actual — reconcile feature covers real-world drift instead. Aggregates are indexed SQL; thousands of rows are trivial.
3. **Transfers are one row, two accounts.** Prevents the classic double-entry duplication bugs; all balance/report queries handle transfer sign per-account in SQL. Fee posts against source account within same row (feeMinor).
4. **Custom month start.** Every "month" in budgets/reports comes from `PeriodResolver(monthStartDay)`. Salary on the 25th is a first-class citizen. Test edge days (29/30/31 with clamping).
5. **Multi-currency: schema yes, feature later.** currency column on money rows from day 1; MVP enforces home currency in UI. v1.1 adds per-account currency + manual rates + normalized net worth. No FX in reports until then (report queries filter to home currency).
6. **Net worth history**: MVP computes retroactively (balance at date = opening + Σ tx ≤ date — one SQL per point, monthly points). No snapshot table needed yet; add `NetWorthSnapshots` only if perf demands.
7. **Deleting things**: accounts/categories with history archive instead of delete (or merge for categories). Transactions hard-delete with undo. Backup before "clear data" is offered automatically.
8. **App lock is UX security, not encryption.** DB is not encrypted in MVP (state honestly in privacy policy; the OS sandbox is real protection). SQLCipher evaluated for v1.1 if demanded — costs Drift setup complexity.

---

## 9. Testing Plan (TDD, 80%+)

- **Unit**: Money arithmetic/rounding/formatting; keypad expression evaluator (precedence, chained ops, divide-by-zero, 2-decimal currencies); PeriodResolver (month-start 1/15/25/29/31, year boundaries); recurring `advance()` (month-end clamp, leap years, intervals, count/end termination); budget threshold notification logic; backup serialize/parse/version-check.
- **DB tests (in-memory Drift)**: balance query vs hand-computed fixtures (incl. transfers + fees + adjustments); month summary excludes transfers; category rollup; cascade/merge behaviors; recurring catch-up posts exactly-once (idempotency across "app reopened twice"); debt remaining math; migration goldens.
- **Widget**: CalcKeypad interactions; add-transaction happy path; budget bar states; month switcher; lock screen gate (PIN wrong/right); amount blur toggle.
- **Integration**: onboarding → create accounts → add 10 mixed transactions (incl. transfer) → verify home numbers → set budget → cross 80% → month report matches → backup export → clear → import → numbers identical. This one test is the app's conscience.
- CI: analyze + test + 80% coverage gate (exclude generated).

---

## 10. Milestones (build order)

1. **M0 — Scaffold (½–1 day)**: project, lints, CI, theme, router+shell, Drift schema+seed, Money type + keypad evaluator (TDD first — it's pure logic), PeriodResolver (TDD).
2. **M1 — Accounts + transactions core (3 days)**: accounts CRUD, add/edit transaction screen with keypad, transaction list + grouping + month switcher, balances live, transfers, detail sheet, delete/undo, duplicate.
3. **M2 — Categories + search/filters (1–2 days)**: manage screens, category sheet in add flow, payee autocomplete, search + filter sheet, multi-select ops.
4. **M3 — Budgets + reports (2 days)**: budgets CRUD+progress+notifications; reports tabs with charts; CSV export.
5. **M4 — Recurring + debts (2 days)**: rules CRUD, engine + catch-up + workmanager + notifications, upcoming screen; debts full feature.
6. **M5 — Security + backup + settings + onboarding (1–2 days)**: PIN/biometric/lock gate/privacy blur; JSON backup/import; settings; onboarding; reconcile.
7. **M6 — Polish (1–2 days)**: animations, haptics, empty states, dark/large-font audits, app icon + splash.
8. **M7 — Release (½ day)**: same checklist as CartList (§11 there). App id `com.abdullahsaad5.ledgr` (confirm). Data Safety: "no data collected" (offline). Category: Finance. Note: finance-category apps get extra Play review scrutiny — the "no network permission" fact helps; do NOT use words like "banking" in listing.

---

## 11. Risks / Open Decisions

- Name collision check before listing (Paisa/Ledger names crowded in Finance category).
- Play finance-app policy review: pure expense trackers are fine, but avoid any wording implying financial services/advice.
- Recurring engine correctness is the top defect risk — it gets the deepest test suite and ships behind careful QA of catch-up scenarios (device off for a month).
- SQLCipher decision deferred; revisit on user demand (v1.1 gate).
- Widgets need Android Kotlin glue (same as CartList — shared learning).
- Ingestion (§3.3): never request `READ_SMS` (Play rejection risk for finance apps) — notification listener only; Gmail `gmail.readonly` restricted-scope verification + CASA assessment has weeks-to-months lead time and possible cost — start that process early, ship notification ingestion first, keep email behind flag.

---

## 12. What NOT to build in v1 (scope fence)

Bank sync/APIs, SMS/notification/email ingestion (fully specced in §3.3 — v2 phase, do not start early), OCR receipts, cloud accounts/sync, investments tracking beyond manual value, split transactions, shared wallets, AI categorization, in-app purchase. Each is a deliberate v2+ item; do not let them creep.
