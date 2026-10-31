import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/categories/screens/category_memory_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dev/dev_screen.dart';
import '../features/import/screens/import_screen.dart';
import '../features/review/screens/review_screen.dart';
import '../features/review/screens/review_screen_args.dart';
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
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
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
          initialStep: (int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 0).clamp(0, 3),
        ),
      ),
      GoRoute(
        path: '/review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ReviewScreen(args: state.extra as ReviewScreenArgs),
      ),
      if (kDebugMode) GoRoute(path: '/dev', builder: (context, state) => const DevScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/import', builder: (context, state) => const ImportScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoryMemoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
