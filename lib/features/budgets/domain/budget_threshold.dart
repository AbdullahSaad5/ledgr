/// Which budget threshold a spend change has just crossed.
enum BudgetThreshold { none, eighty, hundred }

/// Detects the highest budget threshold newly crossed when spending moves from
/// [beforeMinor] to [afterMinor] against [limitMinor]. Pure logic so it can be
/// unit-tested without a database. A non-positive limit never triggers.
BudgetThreshold crossedThreshold({
  required int beforeMinor,
  required int afterMinor,
  required int limitMinor,
}) {
  if (limitMinor <= 0 || afterMinor <= beforeMinor) return BudgetThreshold.none;
  // Integer comparison of x/limit >= ratio  <=>  x * 100 >= ratio100 * limit.
  bool crosses(int ratio100) =>
      beforeMinor * 100 < ratio100 * limitMinor &&
      afterMinor * 100 >= ratio100 * limitMinor;

  if (crosses(100)) return BudgetThreshold.hundred;
  if (crosses(80)) return BudgetThreshold.eighty;
  return BudgetThreshold.none;
}
