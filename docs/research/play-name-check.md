# Play Store collision + policy check for "Ledgr" (#4)

Date: 2026-07-10 · App id: `com.abdullahsaad5.ledgr` (locked pre-upload)

## Verdict: **GO** — keep "Ledgr", but list with a descriptive suffix

Nothing forces a re-lock of the name or the application id. Two caveats
shape the listing, not the name: exact-name collisions hurt
discoverability (use a suffixed display name), and finance-category
paperwork is mandatory (declaration + testing gate below).

## 1. Play collisions

Play search for "ledgr" surfaces **three existing apps named exactly
"Ledgr", all in expense/budget tracking**:

| App | Developer |
|---|---|
| Ledgr: Auto Expense Tracker | Kapav |
| Ledgr | Sri Nandhi KKC |
| Ledgr: Expense Budget Tracker | Baris Fahri Kahriman |

All are small indie apps (no listed install counts in search results —
none is a household brand). Adjacent: "Ledger Wallet™ crypto app"
(Ledger SAS, 4.6★, huge), "Pocket Ledger", "Ledgar AI", "Ledgi".

Consequences:
- **No policy block.** Play allows duplicate display names; identity is
  the app id, which is unique (`com.abdullahsaad5.ledgr`).
- **Discoverability is the real cost.** A bare "Ledgr" listing competes
  with three same-named apps and the Ledger crypto giant on the same
  query. Recommendation: suffixed display name, e.g. **"Ledgr: Money &
  Budget Tracker"** or **"Ledgr — Offline Expense Tracker"** (the
  offline/privacy angle is the differentiator no competitor claims).
  Final wording is a listing-copy decision (already in the map's fog).

## 2. Trademark sanity (Ledger SAS)

- Ledger SAS owns LEDGER word + logo marks for **cryptocurrency
  hardware wallets and related software** (Ledger Nano/Stax/Flex/Live).
- Their litigation record is consumer/security class actions and
  anti-phishing domain disputes (WIPO) — impersonation scams around
  crypto. No record found of them policing "ledger"-derived names for
  unrelated bookkeeping/budget apps.
- "Ledger" is generic/descriptive in accounting; dozens of finance apps
  use it (Pocket Ledger, LEDGERS, Ledgar…). A budget tracker with no
  crypto features, distinct icon (Mint Field), and distinct trade dress
  is safely distant.
- **Guardrails:** never add crypto/wallet features or wording under
  this name; don't imitate Ledger's black/orange branding; the
  suffixed display name further separates the mark.

## 3. Finance-category listing constraints

- **Financial features declaration is mandatory** for every app on any
  track (closed testing included): Play Console → App content →
  Financial features. Ledgr declares no regulated features — it offers
  no loans, investments, trading, or personalized financial advice.
  Expect extra reviewer scrutiny in Finance; the **no-network-permission
  fact is the strongest evidence** and belongs in the listing.
- **Wording bans (PLAN.md §10 M7 confirmed):** avoid "banking",
  "financial services", "investment" in title/description. Safe frame:
  "personal expense tracker", "budget", "money manager".
- **Data safety:** "No data collected" — truthful, since v1 has no
  network permission at all.
- **Closed-testing gate:** personal developer accounts created after
  2023-11-13 must run a closed test with **≥12 opted-in testers for 14
  consecutive days** (reduced from 20 on 2024-12-11) before applying
  for production. Whether Saad's account is subject depends on its
  creation date — confirm in #5. Testers who opt out mid-window reset
  their own 14-day clock.

## Sources

- Play search "ledgr" (2026-07-10)
- [App testing requirements for new personal developer accounts — Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Financial features declaration — Play Console Help](https://support.google.com/googleplay/android-developer/answer/13849271)
- [Financial Services policy — Play Console Help](https://support.google.com/googleplay/android-developer/answer/9876821)
- [Ledger SAS consumer-deception ruling — Bloomberg Law](https://news.bloomberglaw.com/litigation/ledger-sas-fails-to-get-consumer-deception-suit-booted-to-france)
- [WIPO domain dispute DPH2024-0004 (Ledger phishing)](https://www.wipo.int/amc/en/domains/search/text.jsp?case=DPH2024-0004)
- [Ledger trademarks — Ledger terms](https://shop.ledger.com/pages/website-terms-of-use)
