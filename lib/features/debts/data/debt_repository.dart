import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

/// A debt with its computed remaining balance.
class DebtWithRemaining {
  const DebtWithRemaining({required this.debt, required this.paidMinor});
  final Debt debt;
  final int paidMinor;

  int get remainingMinor => debt.principalMinor - paidMinor;
  bool get isOverdue =>
      !debt.settled &&
      debt.dueDate != null &&
      debt.dueDate!.isBefore(DateTime.now());
}

/// Debts (money lent and borrowed) and their repayments (PLAN.md §3.1/§6.8).
class DebtRepository {
  DebtRepository(this._db, this._tx);

  final AppDatabase _db;
  final TransactionRepository _tx;

  Stream<List<DebtWithRemaining>> watchByDirection(DebtDirection direction) {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.debts, _db.debtPayments})
        .watch()
        .asyncMap((_) async {
          final debts =
              await (_db.select(_db.debts)
                    ..where(
                      (d) =>
                          d.direction.equalsValue(direction) &
                          d.deletedAt.isNull(),
                    )
                    ..orderBy([(d) => OrderingTerm(expression: d.settled)]))
                  .get();
          return [
            for (final d in debts)
              DebtWithRemaining(debt: d, paidMinor: await _paid(d.id)),
          ];
        });
  }

  Future<int> _paid(int debtId) async {
    final sum = _db.debtPayments.amountMinor.sum();
    final row =
        await (_db.selectOnly(_db.debtPayments)
              ..addColumns([sum])
              ..where(_db.debtPayments.debtId.equals(debtId)))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  /// Create a debt. If [accountId] is given, the principal also posts a
  /// transaction (money leaving for a loan, arriving for a borrowing).
  Future<int> create({
    required String person,
    required DebtDirection direction,
    required int principalMinor,
    required String currency,
    int? accountId,
    DateTime? dueDate,
    String? note,
  }) async {
    final id = await _db
        .into(_db.debts)
        .insert(
          DebtsCompanion.insert(
            person: person,
            direction: direction,
            principalMinor: principalMinor,
            currency: currency,
            date: DateTime.now(),
            dueDate: Value(dueDate),
            note: Value(note),
          ),
        );
    if (accountId != null) {
      // Lending money leaves the account (expense); borrowing brings it in.
      await _tx.create(
        TransactionDraft(
          type: direction == DebtDirection.lent
              ? TxType.expense
              : TxType.income,
          amountMinor: principalMinor,
          currency: currency,
          accountId: accountId,
          date: DateTime.now(),
          payee: person,
          note: 'Debt: $person',
          debtId: id,
        ),
      );
    }
    return id;
  }

  /// Record a repayment. If [accountId] is given it also posts the reverse
  /// transaction. Settles the debt when fully repaid.
  Future<void> addPayment(
    DebtWithRemaining debt, {
    required int amountMinor,
    int? accountId,
  }) async {
    await _db.transaction(() async {
      int? txId;
      if (accountId != null) {
        txId = await _tx.create(
          TransactionDraft(
            // Repayment of money we lent comes back in (income); repaying
            // what we borrowed goes out (expense).
            type: debt.debt.direction == DebtDirection.lent
                ? TxType.income
                : TxType.expense,
            amountMinor: amountMinor,
            currency: debt.debt.currency,
            accountId: accountId,
            date: DateTime.now(),
            payee: debt.debt.person,
            note: 'Debt repayment: ${debt.debt.person}',
            debtId: debt.debt.id,
          ),
        );
      }
      await _db
          .into(_db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              debtId: debt.debt.id,
              amountMinor: amountMinor,
              date: DateTime.now(),
              transactionId: Value(txId),
            ),
          );
      final paid = await _paid(debt.debt.id);
      if (paid >= debt.debt.principalMinor) {
        await settle(debt.debt.id);
      }
    });
  }

  Future<void> settle(int id) {
    return (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(
        settled: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
