import 'package:ledgr/core/db/enums.dart';

/// The user's intent to create or edit a transaction, before it becomes a row.
/// Shared by the add/edit screen and the transaction repository.
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.feeMinor,
    this.categoryId,
    this.payee,
    this.note,
  });

  final TxType type;
  final int amountMinor;
  final String currency;
  final int accountId;
  final int? toAccountId;
  final int? feeMinor;
  final int? categoryId;
  final String? payee;
  final String? note;
  final DateTime date;

  bool get isTransfer => type == TxType.transfer;

  /// Validates cross-field invariants (ADR-0004). Throws [ArgumentError].
  void validate() {
    if (amountMinor <= 0 && type != TxType.adjustment) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'must be positive');
    }
    if (isTransfer) {
      if (toAccountId == null) {
        throw ArgumentError('transfer requires a destination account');
      }
      if (toAccountId == accountId) {
        throw ArgumentError('transfer source and destination must differ');
      }
    } else if (toAccountId != null) {
      throw ArgumentError('only transfers may set a destination account');
    }
  }
}
