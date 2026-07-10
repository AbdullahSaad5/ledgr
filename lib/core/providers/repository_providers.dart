import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/notifications/notification_service.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/attachments/data/attachment_repository.dart';
import 'package:ledgr/features/backup/data/backup_service.dart';
import 'package:ledgr/features/budgets/data/budget_alert_service.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/categories/data/category_repository.dart';
import 'package:ledgr/features/debts/data/debt_reminder_service.dart';
import 'package:ledgr/features/debts/data/debt_repository.dart';
import 'package:ledgr/features/recurring/data/recurring_repository.dart';
import 'package:ledgr/features/reports/data/reports_repository.dart';
import 'package:ledgr/features/reports/domain/report_models.dart';
import 'package:ledgr/features/tags/data/tag_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';
import 'package:ledgr/features/transactions/domain/transaction_filter.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => TagRepository(ref.watch(databaseProvider)),
);

final attachmentRepositoryProvider = Provider<AttachmentRepository>(
  (ref) => AttachmentRepository(ref.watch(databaseProvider)),
);

/// Receipt images for one transaction, live.
final attachmentsProvider = StreamProvider.family<List<Attachment>, int>(
  (ref, transactionId) => ref
      .watch(attachmentRepositoryProvider)
      .watchForTransaction(transactionId),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(
    ref.watch(databaseProvider),
    ref.watch(periodResolverProvider),
  ),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(
    ref.watch(databaseProvider),
    ref.watch(periodResolverProvider),
  ),
);

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(
    ref.watch(databaseProvider),
    ref.watch(transactionRepositoryProvider),
  ),
);

final activeRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchActive(),
);

final upcomingProvider = StreamProvider<List<UpcomingItem>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchUpcoming(),
);

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(
    ref.watch(databaseProvider),
    ref.watch(transactionRepositoryProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

final debtsByDirectionProvider =
    StreamProvider.family<List<DebtWithRemaining>, DebtDirection>(
      (ref, direction) =>
          ref.watch(debtRepositoryProvider).watchByDirection(direction),
    );

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final debtReminderServiceProvider = Provider<DebtReminderService>(
  (ref) => DebtReminderService(
    ref.watch(databaseProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(moneyFormatterProvider),
  ),
);

final budgetAlertServiceProvider = Provider<BudgetAlertService>(
  (ref) => BudgetAlertService(
    ref.watch(budgetRepositoryProvider),
    ref.watch(notificationServiceProvider),
  ),
);

/// Live budget progress for the selected period.
final budgetProgressProvider = StreamProvider<List<BudgetProgress>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(budgetRepositoryProvider).watchProgress(period);
});

// Report snapshots for the selected period — live streams that re-run on
// any money-affecting DB change so the dashboard and reports update in
// realtime.
final spendByCategoryProvider = StreamProvider<List<CategorySpend>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchSpendByCategory(period);
});

/// Child breakdown of one parent category for the selected period (#16).
final spendByChildrenProvider = StreamProvider.family<List<CategorySpend>, int>(
  (ref, parentId) {
    final period = ref.watch(selectedPeriodProvider);
    return ref
        .watch(reportsRepositoryProvider)
        .watchSpendByChildren(parentId, period);
  },
);

final monthTotalsProvider = StreamProvider<MonthPoint>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchMonthTotals(period);
});

final topPayeesProvider = StreamProvider<List<PayeeTotal>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchTopPayees(period);
});

final monthlyTrendProvider = StreamProvider<List<MonthPoint>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchMonthlyTrend(period);
});

final netWorthSeriesProvider = StreamProvider<List<NetWorthPoint>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchNetWorthSeries(period);
});

final allTagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(tagRepositoryProvider).watchAll(),
);

/// The active search/filter criteria for the search screen.
final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => const TransactionFilter(),
);

final filteredTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final filter = ref.watch(transactionFilterProvider);
  return ref.watch(transactionRepositoryProvider).watchFiltered(filter);
});

/// Active accounts with live balances (dashboard + accounts list).
final activeAccountsProvider = StreamProvider<List<AccountWithBalance>>(
  (ref) => ref.watch(accountRepositoryProvider).watchActiveWithBalances(),
);

/// Plain active-accounts stream for pickers.
final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchActive(),
);

/// Active accounts keyed by id, for resolving names in transaction rows.
final accountMapProvider = Provider<Map<int, Account>>((ref) {
  final list = ref.watch(accountsProvider).valueOrNull ?? const [];
  return {for (final a in list) a.id: a};
});

/// The reporting period currently shown in the transactions/reports views.
final selectedPeriodProvider = StateProvider<Period>(
  (ref) => ref.watch(periodResolverProvider).periodContaining(DateTime.now()),
);

/// The period immediately before the selected one (for comparisons).
final previousPeriodProvider = Provider<Period>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(periodResolverProvider).previous(period);
});

/// Transactions of the previous period (spending-pace comparisons).
final previousPeriodTransactionsProvider = StreamProvider<List<Transaction>>((
  ref,
) {
  final period = ref.watch(previousPeriodProvider);
  return ref.watch(transactionRepositoryProvider).watchInPeriod(period);
});

/// Category spend of the previous period (category-shift comparisons).
final previousSpendByCategoryProvider = StreamProvider<List<CategorySpend>>((
  ref,
) {
  final period = ref.watch(previousPeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchSpendByCategory(period);
});

/// Transactions inside [selectedPeriodProvider], newest first.
final periodTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(transactionRepositoryProvider).watchInPeriod(period);
});

/// Ids selected in the transactions-list multi-select mode.
final selectedTransactionsProvider = StateProvider<Set<int>>((ref) => {});

final accountByIdProvider = StreamProvider.family<Account, int>(
  (ref, id) => ref.watch(accountRepositoryProvider).watchById(id),
);

final accountBalanceProvider = StreamProvider.family<int, int>(
  (ref, id) => ref.watch(accountRepositoryProvider).watchBalance(id),
);

final accountHistoryProvider = StreamProvider.family<List<Transaction>, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).watchForAccount(id),
);

final transactionByIdProvider = StreamProvider.family<Transaction, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).watchById(id),
);

/// Net worth = sum of balances of accounts flagged include-in-net-worth.
final netWorthProvider = Provider<AsyncValue<int>>((ref) {
  final accounts = ref.watch(activeAccountsProvider);
  return accounts.whenData(
    (list) => list
        .where((e) => e.account.includeInNetWorth)
        .fold(0, (sum, e) => sum + e.balanceMinor),
  );
});

final categoriesByKindProvider =
    StreamProvider.family<List<Category>, CategoryKind>(
      (ref, kind) => ref.watch(categoryRepositoryProvider).watchByKind(kind),
    );

final allCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// Categories keyed by id, for resolving a transaction's category icon/name.
final categoryMapProvider = Provider<Map<int, Category>>((ref) {
  final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
  return {for (final c in categories) c.id: c};
});
