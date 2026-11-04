import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import 'log/error_hooks.dart';
import '../features/accounts/screens/accounts_settings_screen.dart';
import '../features/accounts/screens/account_screen.dart';
import '../features/backups/screens/backups_screen.dart';
import '../features/budget/screens/budget_screen.dart';
import '../features/categories/screens/categories_screen.dart';
import '../features/categories/screens/category_memory_screen.dart';
import '../features/categories/screens/match_categories_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dev/dev_screen.dart';
import '../features/diagnostics/diagnostics_screen.dart';
import '../features/import/screens/import_screen.dart';
import '../features/quick_add/screens/quick_add_screen.dart';
import '../features/review/screens/review_screen.dart';
import '../features/review/screens/review_screen_args.dart';
import '../features/settings/screens/actual_settings_screen.dart';
import '../features/settings/screens/backend_settings_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/setup/screens/setup_screen.dart';
import '../features/welcome/screens/welcome_screen.dart';
import 'app_shell.dart';

export '../features/review/screens/review_screen_args.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable before onboarding is finished.
const _openRoutes = {'/welcome', '/setup', '/dev'};

/// Built once (a Provider, not watched elsewhere) so the GoRouter instance
/// stays stable for the app's lifetime; the onboarding gate is enforced via
/// `redirect`, which go_router re-evaluates on every navigation, rather
/// than by rebuilding the whole router when settings change.
final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.read(appConfigProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Without a budget there is nothing to show on Home yet: start where
    // the app already works.
    initialLocation: config.budgetSyncId == null ? '/import' : '/dashboard',
    observers: [LogNavigatorObserver()],
    redirect: (context, state) {
      final onboarded = ref.read(appConfigProvider).onboarded;
      final location = state.matchedLocation;
      if (!onboarded && !_openRoutes.contains(location)) return '/welcome';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(
        path: '/setup',
        builder: (context, state) => SetupScreen(
          initialStep: (int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 0).clamp(0, SetupScreen.lastStep),
        ),
      ),
      GoRoute(
        path: '/review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ReviewScreen(args: state.extra as ReviewScreenArgs),
      ),
      GoRoute(
        path: '/match-categories',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MatchCategoriesScreen(),
      ),
      GoRoute(
        path: '/add',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: QuickAddScreen()),
      ),
      if (kDebugMode) GoRoute(path: '/dev', builder: (context, state) => const DevScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'accounts/:id',
                    builder: (context, state) => AccountScreen(
                      accountId: state.pathParameters['id']!,
                      accountName: state.extra as String?,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/budget', builder: (context, state) => const BudgetScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/import', builder: (context, state) => const ImportScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'backend',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const BackendSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'actual',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ActualSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'accounts',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AccountsSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'categories',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CategoryMemoryScreen(),
                  ),
                  GoRoute(
                    path: 'category-list',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'backups',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const BackupsScreen(),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const DiagnosticsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
