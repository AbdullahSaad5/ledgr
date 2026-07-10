# Ledgr E2E test plan (emulator, release build)

Manual/scripted flows run on the Pixel 8 Pro emulator against a wiped install.
Every step carries an expected value derived from one running ledger, so any
screen that disagrees with the ledger is a bug — either in math or in
realtime propagation.

**Ledger convention:** PKR, integer minor units under the hood. "Cash 28,000"
means Rs 28,000.00.

## Running ledger (expected state after each TC)

| After | Cash | Bank | Net worth | Period spent | Period received |
|-------|------|------|-----------|--------------|-----------------|
| TC-01 onboard, Cash opening 10,000 | 10,000 | — | 10,000 | 0 | 0 |
| TC-02 expense 1,250 Food (Cafe) | 8,750 | — | 8,750 | 1,250 | 0 |
| TC-03 expense 500+250=750 Groceries (Mart) | 8,000 | — | 8,000 | 2,000 | 0 |
| TC-04 income 25,000 Salary (Employer) | 33,000 | — | 33,000 | 2,000 | 25,000 |
| TC-05 account Bank opening 50,000 | 33,000 | 50,000 | 83,000 | 2,000 | 25,000 |
| TC-06 transfer 5,000 Cash→Bank | 28,000 | 55,000 | 83,000 | 2,000 | 25,000 |
| TC-09 edit TC-02 1,250→2,250 | 27,000 | 55,000 | 82,000 | 3,000 | 25,000 |
| TC-11 reconcile Bank to 54,500 | 27,000 | 54,500 | 81,500 | 3,000 | 25,000 |

## Test cases

### Core money flows

- **TC-01 Onboarding.** Wipe data → launch → complete onboarding, currency
  PKR, first account Cash type cash, opening balance 10,000.
  Expect: land on home, net worth Rs 10,000, accounts carousel shows Cash,
  empty recent activity.
- **TC-02 Basic expense.** FAB → Expense preselected → keypad 1250 → payee
  "Cafe" → category Food & Dining → Save.
  Expect: home net worth 8,750, Spent 1,250, tx in recent activity; Cash card
  8,750; transactions tab lists it under today.
- **TC-03 Calculator expense.** FAB → 500 + 250 → amount preview evaluates →
  category Groceries, payee "Mart" → Save. Expect ledger row TC-03.
- **TC-04 Income.** FAB → Income → 25000 → category Salary, payee "Employer"
  → Save. Expect Received 25,000, net worth 33,000.
- **TC-05 Second account.** Accounts → New account "Bank", type bank, opening
  50,000. Expect net worth 83,000, two cards in carousel.
- **TC-06 Transfer.** FAB → Transfer → 5000 → To = Bank → Save.
  Expect: Cash 28,000, Bank 55,000, net worth UNCHANGED 83,000, Spent/Received
  unchanged (transfers are not flow), single row in transactions showing both
  accounts.
- **TC-07 Overall budget.** Budgets → Add budget → Overall, limit 10,000.
  Expect: 2,000 spent → 20%, "Rs 8,000.00 left". Home shows budget bar.
- **TC-08 Category budget.** Add budget → Category = Food & Dining, limit
  1,500. Expect: 1,250 spent → 83%, near-limit warning styling.
- **TC-09 Edit ripples everywhere.** Edit the TC-02 expense 1,250 → 2,250.
  Expect (no restart, realtime): Cash 27,000, net worth 82,000, overall budget
  3,000/10,000 = 30%, Food budget 2,250/1,500 = 150% overspent (over-limit
  styling), reports expense total 3,000.
- **TC-10 Delete + undo.** Swipe-delete the Groceries 750 expense → snackbar
  Undo → tap Undo. Expect: numbers dip by 750 then return to ledger row TC-09
  after undo.
- **TC-11 Reconcile.** Bank → reconcile to 54,500. Expect: adjustment tx
  −500 created, Bank card 54,500, net worth 81,500 immediately.

### Reports coherence (after TC-11)

- **TC-12 Overview tab.** Income 25,000, Expense 3,000. Donut: Food 2,250
  (75%), Groceries 750 (25%), no Uncategorized. Daily rhythm bar on today.
  Top payee Cafe 2,250.
- **TC-13 Trends tab.** Daily average = 3,000 / day-of-month. Projected total
  = average × days-in-month, colored vs overall budget 10,000. Biggest expense
  2,250 (Cafe). Top category Food 75%.
- **TC-14 Net worth tab.** Headline 81,500 equals home. Composition: Bank
  ~67%, Cash ~33%.

### Navigation, filters, periods

- **TC-15 Period switcher.** Transactions/budgets/reports → previous month:
  all zero/empty; return to current: ledger restored. Prev-month budget shows
  0 spent (budgets are per-period).
- **TC-16 Search + filters.** Search "Cafe" → exactly the edited 2,250 tx.
  Filter type=Income → only Salary. Filter account=Bank → transfer + adjustment.
- **TC-17 Tab back-and-forth.** Home → Reports → Home → Transactions rapidly;
  no frozen tab, no stale numbers.
- **TC-18 Detail sheet + duplicate.** Tap TC-02 tx → detail sheet: amount,
  account, category, date correct. Duplicate → spent +2,250 → delete duplicate
  → numbers restore.

### Secondary features

- **TC-19 Recurring.** Menu → Recurring → create "Internet" expense 2,000
  monthly from Cash. Expect: listed with next-due date; no tx posted yet
  (unless due today and auto-post on).
- **TC-20 Debts.** Menu → Debts → add "Ali owes me" 5,000 → record payment
  2,000. Expect remaining 3,000; if payments post to an account, Cash +2,000
  (note actual behavior).
- **TC-21 Tags.** Add tag "work" to a tx; filter by tag finds it.
- **TC-22 Payee memory.** New expense → payee sheet → typing "Ca" suggests
  "Cafe"; picking it auto-fills category Food & Dining.

### Alternate / edge flows

- **TC-23 Zero amount blocked.** FAB → Save with 0.00 → toast "Enter an
  amount", nothing saved.
- **TC-24 Transfer needs destination.** Transfer → amount → Save without To →
  toast, nothing saved.
- **TC-25 Large values.** Expense 9,999,999.99 → hero amount fits (FittedBox),
  home/report cards don't overflow → delete it, ledger restores.
- **TC-26 Dark mode.** Settings → dark theme → home, reports, budgets, add-tx
  all render dark without artifacts; toggle back.
- **TC-27 App restart persistence.** Force-stop + relaunch → all ledger
  numbers identical (DB is source of truth).

## Results log

Filled in per run — see the session notes / commit messages for fixes.
