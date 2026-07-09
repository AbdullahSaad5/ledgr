import 'package:ledgr/core/notifications/notification_service.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/budgets/domain/budget_threshold.dart';

/// Fires budget-threshold notifications after an expense is recorded. Checks
/// each active budget the expense touched: if adding the amount pushed its
/// spend across 80% or 100%, notifies once (PLAN.md §3.1).
class BudgetAlertService {
  BudgetAlertService(this._budgets, this._notifications);

  final BudgetRepository _budgets;
  final NotificationService _notifications;

  Future<void> onExpenseRecorded({
    required int amountMinor,
    required int? categoryId,
    required Period period,
  }) async {
    if (amountMinor <= 0) return;
    final budgets = await _budgets.watchActive().first;
    for (final budget in budgets) {
      // A category budget only reacts to its own category (or a child).
      if (budget.categoryId != null && budget.categoryId != categoryId) {
        continue;
      }
      final after = await _budgets.spentFor(budget, period);
      final before = after - amountMinor;
      final crossing = crossedThreshold(
        beforeMinor: before,
        afterMinor: after,
        limitMinor: budget.limitMinor,
      );
      if (crossing == BudgetThreshold.none) continue;
      final pct = crossing == BudgetThreshold.hundred ? 100 : 80;
      await _notifications.show(
        id: budget.id,
        title: 'Budget alert',
        body: crossing == BudgetThreshold.hundred
            ? 'You have reached your budget limit.'
            : "You've used $pct% of a budget.",
      );
    }
  }
}
