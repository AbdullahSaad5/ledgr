import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/categories/data/category_repository.dart';
import 'package:ledgr/features/transactions/data/transaction_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

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

/// Transactions inside [selectedPeriodProvider], newest first.
final periodTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(transactionRepositoryProvider).watchInPeriod(period);
});

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
