import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';

/// Money views over generated Drift rows. Keeps `amountMinor`/`currency`
/// column pairs out of the UI (ADR-0002).
extension AccountMoney on Account {
  Money get openingBalance =>
      Money(minor: openingBalanceMinor, currency: currency);

  Money? get creditLimit => creditLimitMinor == null
      ? null
      : Money(minor: creditLimitMinor!, currency: currency);
}

extension TransactionMoney on Transaction {
  Money get amount => Money(minor: amountMinor, currency: currency);

  Money? get fee =>
      feeMinor == null ? null : Money(minor: feeMinor!, currency: currency);

  /// The signed effect of this transaction on [forAccount]'s balance, in minor
  /// units (ADR-0004). Positive = money in, negative = money out.
  int signedMinorFor(int forAccount) {
    switch (type) {
      case TxType.income:
        return accountId == forAccount ? amountMinor : 0;
      case TxType.expense:
        return accountId == forAccount ? -amountMinor : 0;
      case TxType.adjustment:
        // Adjustments store a signed delta directly.
        return accountId == forAccount ? amountMinor : 0;
      case TxType.transfer:
        if (accountId == forAccount) {
          return -amountMinor - (feeMinor ?? 0);
        }
        if (toAccountId == forAccount) {
          return amountMinor;
        }
        return 0;
    }
  }

  /// Signed [Money] effect on [forAccount].
  Money signedAmountFor(int forAccount) =>
      Money(minor: signedMinorFor(forAccount), currency: currency);
}
