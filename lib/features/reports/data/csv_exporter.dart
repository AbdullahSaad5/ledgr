import 'package:ledgr/core/db/database.dart';

/// Serializes transactions to CSV for export/sharing.
abstract final class CsvExporter {
  static String transactionsToCsv(
    List<Transaction> transactions, {
    required Map<int, String> accountNames,
    required Map<int, String> categoryNames,
    required String Function(int minor) formatAmount,
  }) {
    final buffer = StringBuffer()
      ..writeln('Date,Type,Amount,Account,Category,Payee,Note');
    for (final t in transactions) {
      final row = [
        t.date.toIso8601String().split('T').first,
        t.type.name,
        formatAmount(t.amountMinor),
        accountNames[t.accountId] ?? '',
        if (t.categoryId == null) '' else categoryNames[t.categoryId] ?? '',
        t.payee ?? '',
        t.note ?? '',
      ].map(_escape).join(',');
      buffer.writeln(row);
    }
    return buffer.toString();
  }

  static String _escape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
