import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledgr/core/db/database.dart';

/// Full local backup: exports every table to a versioned JSON envelope and
/// restores from it (replace-all). Uuids are included so a restore-then-sync
/// (v2) doesn't duplicate. Note: receipt image files are not part of v1 JSON.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const int version = 1;

  Future<String> export() async {
    final tables = <String, List<Map<String, dynamic>>>{
      'accounts': await _dump(_db.accounts),
      'categories': await _dump(_db.categories),
      'transactions': await _dump(_db.transactions),
      'tags': await _dump(_db.tags),
      'transactionTags': await _dump(_db.transactionTags),
      'attachments': await _dump(_db.attachments),
      'budgets': await _dump(_db.budgets),
      'recurringRules': await _dump(_db.recurringRules),
      'debts': await _dump(_db.debts),
      'debtPayments': await _dump(_db.debtPayments),
    };
    return jsonEncode({'version': version, 'tables': tables});
  }

  Future<void> import(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final fileVersion = data['version'] as int?;
    if (fileVersion != version) {
      throw FormatException('Unsupported backup version: $fileVersion');
    }
    final t = (data['tables'] as Map).cast<String, dynamic>();

    await _db.transaction(() async {
      // Defer FK checks so insertion order and self-references don't matter.
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in _db.allTables) {
        await _db.delete(table).go();
      }

      await _load(_db.accounts, t['accounts'], Account.fromJson);
      await _load(_db.categories, t['categories'], Category.fromJson);
      await _load(_db.transactions, t['transactions'], Transaction.fromJson);
      await _load(_db.tags, t['tags'], Tag.fromJson);
      await _load(
        _db.transactionTags,
        t['transactionTags'],
        TransactionTag.fromJson,
      );
      await _load(_db.attachments, t['attachments'], Attachment.fromJson);
      await _load(_db.budgets, t['budgets'], Budget.fromJson);
      await _load(
        _db.recurringRules,
        t['recurringRules'],
        RecurringRule.fromJson,
      );
      await _load(_db.debts, t['debts'], Debt.fromJson);
      await _load(_db.debtPayments, t['debtPayments'], DebtPayment.fromJson);
    });
  }

  Future<List<Map<String, dynamic>>>
  _dump<T extends Table, D extends DataClass>(TableInfo<T, D> table) async {
    final rows = await _db.select(table).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<void> _load<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    dynamic rows,
    D Function(Map<String, dynamic>) fromJson,
  ) async {
    if (rows == null) return;
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      // Drift data classes implement Insertable; the generic bound can't prove
      // it, so cast.
      await _db
          .into(table)
          .insert(
            fromJson(row) as Insertable<D>,
            mode: InsertMode.insertOrReplace,
          );
    }
  }
}
