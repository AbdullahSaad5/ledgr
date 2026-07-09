/// Persisted enums. Stored as their integer index via Drift's `intEnum`, so the
/// **order of these values must never change** — only append. (Reordering would
/// silently reinterpret existing rows.)
library;

enum AccountType { cash, bank, creditCard, wallet, savings, investment, other }

enum CategoryKind { expense, income }

enum TxType { expense, income, transfer, adjustment }

enum Frequency { daily, weekly, monthly, yearly }

enum DebtDirection { lent, borrowed }
