import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/server_wakeup_screen.dart';
import '../../features/auth/presentation/setup_register_screen.dart';
import '../../features/backup/presentation/backup_restore_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/financial_analytics_screen.dart';
import '../../features/lock/presentation/lock_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/domain/transaction_model.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../features/transactions/presentation/expense_screen.dart';
import '../../features/transactions/presentation/income_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../security/app_lock_controller.dart';
import '../widgets/main_shell_screen.dart';

class _RouterRefreshChangeNotifier extends ChangeNotifier {
  _RouterRefreshChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) {
      notifyListeners();
    });
    ref.listen<AppLockState>(appLockControllerProvider, (_, __) {
      notifyListeners();
    });
  }
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshChangeNotifier refreshNotifier =
      _RouterRefreshChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/wakeup',
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState auth = ref.read(authControllerProvider);
      final AppLockState lock = ref.read(appLockControllerProvider);
      final String location = state.matchedLocation;

      if (auth.stage == AuthStage.wakingServer) {
        return location == '/wakeup' ? null : '/wakeup';
      }
      if (auth.stage == AuthStage.needsSetup) {
        return location == '/setup' ? null : '/setup';
      }
      if (auth.stage == AuthStage.unauthenticated) {
        return location == '/login' ? null : '/login';
      }

      // Authenticated
      if (lock.hasPin && lock.isLocked) {
        return location == '/lock' ? null : '/lock';
      }

      if (location == '/wakeup' ||
          location == '/setup' ||
          location == '/login' ||
          location == '/lock') {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/wakeup',
        builder: (BuildContext context, GoRouterState state) =>
            const ServerWakeupScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (BuildContext context, GoRouterState state) =>
            const SetupRegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (BuildContext context, GoRouterState state) =>
            const LockScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (BuildContext context, GoRouterState state) =>
            const CategoriesScreen(),
      ),
      GoRoute(
        path: '/backup',
        builder: (BuildContext context, GoRouterState state) =>
            const BackupRestoreScreen(),
      ),
      GoRoute(
        path: '/income',
        builder: (BuildContext context, GoRouterState state) =>
            const IncomeScreen(),
      ),
      GoRoute(
        path: '/expense',
        builder: (BuildContext context, GoRouterState state) =>
            const ExpenseScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (BuildContext context, GoRouterState state) =>
            const FinancialAnalyticsScreen(),
      ),
      GoRoute(
        path: '/transactions/add',
        builder: (BuildContext context, GoRouterState state) {
          final TransactionType? initialType =
              state.extra is TransactionType
              ? state.extra as TransactionType
              : null;
          return AddTransactionScreen(initialType: initialType);
        },
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (BuildContext context, GoRouterState state) {
          final String id = state.pathParameters['id'] ?? '';
          final TransactionModel? extraTx = state.extra is TransactionModel
              ? state.extra as TransactionModel
              : null;
          return TransactionDetailScreen(
            transactionId: id,
            initialTransaction: extraTx,
          );
        },
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (BuildContext context, GoRouterState state) {
          final String id = state.pathParameters['id'] ?? '';
          return AccountDetailScreen(accountId: id);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/transactions',
                builder: (BuildContext context, GoRouterState state) =>
                    const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/accounts',
                builder: (BuildContext context, GoRouterState state) =>
                    const AccountsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
