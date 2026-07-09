import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/app/nav_shell.dart';
import 'package:ledgr/features/accounts/presentation/account_detail_screen.dart';
import 'package:ledgr/features/accounts/presentation/accounts_screen.dart';
import 'package:ledgr/features/budgets/presentation/budgets_screen.dart';
import 'package:ledgr/features/categories/presentation/categories_screen.dart';
import 'package:ledgr/features/home/presentation/home_screen.dart';
import 'package:ledgr/features/reports/presentation/reports_screen.dart';
import 'package:ledgr/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ledgr/features/transactions/presentation/search_screen.dart';
import 'package:ledgr/features/transactions/presentation/transactions_screen.dart';

/// Named routes. Paths live here so navigation never hard-codes strings.
enum AppRoute {
  home('/', 'home'),
  transactions('/transactions', 'transactions'),
  budgets('/budgets', 'budgets'),
  reports('/reports', 'reports'),
  accounts('/accounts', 'accounts'),
  accountDetail('/accounts/:id', 'accountDetail'),
  categories('/categories', 'categories'),
  search('/search', 'search'),
  addTransaction('/tx/new', 'addTransaction'),
  editTransaction('/tx/:id/edit', 'editTransaction');

  const AppRoute(this.path, this.routeName);

  final String path;
  final String routeName;

  String get name => routeName;
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoute.home.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => NavShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.home.path,
                name: AppRoute.home.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.transactions.path,
                name: AppRoute.transactions.name,
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.budgets.path,
                name: AppRoute.budgets.name,
                builder: (context, state) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.reports.path,
                name: AppRoute.reports.name,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.accounts.path,
        name: AppRoute.accounts.name,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: AppRoute.accountDetail.path,
        name: AppRoute.accountDetail.name,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => AccountDetailScreen(
          accountId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoute.categories.path,
        name: AppRoute.categories.name,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoute.search.path,
        name: AppRoute.search.name,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoute.addTransaction.path,
        name: AppRoute.addTransaction.name,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: AddTransactionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoute.editTransaction.path,
        name: AppRoute.editTransaction.name,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: AddTransactionScreen(
            transactionId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
    ],
  );
}
