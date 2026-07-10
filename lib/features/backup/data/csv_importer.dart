import 'package:decimal/decimal.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/categories/data/category_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_draft.dart';

/// What an import run did, for the confirmation snackbar.
class CsvImportSummary {
  const CsvImportSummary({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}

/// Imports transactions from Ledgr's own CSV export format
/// (`Date,Type,Amount,Account,Category,Payee,Note`).
///
/// Accounts and categories are matched by name (case-insensitive) and
/// created when missing; `Parent > Child` paths map onto subcategories.
/// Exact duplicates (same date, type, amount, payee) and transfer rows
/// (the export doesn't carry the target account) are skipped, so importing
/// the same file twice is harmless.
class CsvImporter {
  CsvImporter(this._db)
    : _accounts = AccountRepository(_db),
      _categories = CategoryRepository(_db),
      _transactions = TransactionRepository(_db);

  final AppDatabase _db;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final TransactionRepository _transactions;

  /// RFC-4180-ish parser: quoted fields, `""` escapes, embedded commas and
  /// newlines. Returns data rows (header dropped).
  static List<List<String>> parseRows(String csv) {
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    for (var i = 0; i < csv.length; i++) {
      final c = csv[i];
      if (inQuotes) {
        if (c == '"') {
          final isEscaped = i + 1 < csv.length && csv[i + 1] == '"';
          if (isEscaped) {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field = StringBuffer();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((f) => f.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }
    row.add(field.toString());
    if (row.any((f) => f.isNotEmpty)) rows.add(row);
    return rows.length <= 1 ? const [] : rows.sublist(1);
  }

  /// Parses a formatted amount ("Rs 2,300", "\$3,240.00", "-Rs 500") into
  /// minor units for [currency].
  static int parseAmountMinor(String raw, String currency) {
    final cleaned = raw.replaceAll(RegExp('[^0-9.-]'), '');
    if (cleaned.isEmpty) return 0;
    final value = Decimal.tryParse(cleaned) ?? Decimal.zero;
    return Money.fromDecimal(value, currency).minor;
  }

  Future<CsvImportSummary> import(
    String csv, {
    required String currency,
  }) async {
    var imported = 0;
    var skipped = 0;
    final existing = await _db.select(_db.transactions).get();
    final seen = {
      for (final t in existing)
        _dupeKey(t.date, t.type, t.amountMinor, t.payee),
    };

    for (final row in parseRows(csv)) {
      if (row.length < 7) {
        skipped++;
        continue;
      }
      final date = DateTime.tryParse(row[0]);
      final type = TxType.values.asNameMap()[row[1].trim()];
      final amount = parseAmountMinor(row[2], currency);
      if (date == null || type == null || amount == 0) {
        skipped++;
        continue;
      }
      // Transfers need a target account the export doesn't carry.
      if (type == TxType.transfer) {
        skipped++;
        continue;
      }
      final payee = row[5].trim().isEmpty ? null : row[5].trim();
      final key = _dupeKey(date, type, amount, payee);
      if (seen.contains(key)) {
        skipped++;
        continue;
      }

      final accountId = await _accountIdFor(row[3].trim(), currency);
      final categoryId = await _categoryIdFor(row[4].trim(), type);
      await _transactions.create(
        TransactionDraft(
          type: type,
          amountMinor: amount,
          currency: currency,
          accountId: accountId,
          categoryId: categoryId,
          date: date,
          payee: payee,
          note: row[6].trim().isEmpty ? null : row[6].trim(),
        ),
      );
      seen.add(key);
      imported++;
    }
    return CsvImportSummary(imported: imported, skipped: skipped);
  }

  String _dupeKey(DateTime date, TxType type, int amountMinor, String? payee) {
    final day = DateTime(date.year, date.month, date.day);
    return '$day|${type.name}|$amountMinor|${payee ?? ''}';
  }

  Future<int> _accountIdFor(String name, String currency) async {
    final label = name.isEmpty ? 'Imported' : name;
    final all = await (_db.select(
      _db.accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    final matches = all.where(
      (a) => a.name.toLowerCase() == label.toLowerCase(),
    );
    if (matches.isNotEmpty) return matches.first.id;
    return _accounts.create(
      name: label,
      type: AccountType.other,
      icon: 'more_horiz',
      color: 0xFF607D8B,
      currency: currency,
    );
  }

  Future<int?> _categoryIdFor(String path, TxType type) async {
    if (path.isEmpty) return null;
    final kind = type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final parts = path.split('>').map((p) => p.trim()).toList();

    int? parentId;
    int? resolved;
    for (final part in parts) {
      final all = await _categories.byKind(kind);
      final matches = all.where(
        (c) =>
            c.name.toLowerCase() == part.toLowerCase() &&
            c.parentId == parentId,
      );
      resolved = matches.isNotEmpty
          ? matches.first.id
          : await _categories.create(
              name: part,
              kind: kind,
              icon: 'category',
              color: 0xFF607D8B,
              parentId: parentId,
            );
      parentId = resolved;
    }
    return resolved;
  }
}
