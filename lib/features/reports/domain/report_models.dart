/// Total expense attributed to a (top-level) category over a period.
class CategorySpend {
  const CategorySpend({required this.categoryId, required this.totalMinor});

  /// Sentinel id for spending with no category.
  static const uncategorizedId = -1;

  final int categoryId;
  final int totalMinor;
}

/// A payee and how much was spent with it.
class PayeeTotal {
  const PayeeTotal({required this.payee, required this.totalMinor});
  final String payee;
  final int totalMinor;
}

/// Income and expense for a single reporting period.
class MonthPoint {
  const MonthPoint({
    required this.year,
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });
  final int year;
  final int month;
  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

/// Net worth at a point in time.
class NetWorthPoint {
  const NetWorthPoint({required this.date, required this.minor});
  final DateTime date;
  final int minor;
}
