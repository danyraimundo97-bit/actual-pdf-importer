import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/categories/screens/category_memory_screen.dart';
import '../features/import/screens/import_screen.dart';
import '../features/review/screens/review_screen.dart';
import '../features/review/screens/review_screen_args.dart';
import '../features/settings/screens/settings_screen.dart';

export '../features/review/screens/review_screen_args.dart';

/// Built once (a Provider, not watched elsewhere) so the GoRouter instance
/// stays stable for the app's lifetime; the first-run gate is enforced via
/// `redirect`, which go_router re-evaluates on every navigation, rather
/// than by rebuilding the whole router when settings change.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/import',
    redirect: (context, state) {
      final backendUrl = ref.read(appConfigProvider).backendUrl;
      final hasBackend = backendUrl != null && backendUrl.isNotEmpty;
      final goingToSettings = state.matchedLocation == '/settings';
      if (!hasBackend && !goingToSettings) return '/settings';
      return null;
    },
    routes: [
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/import', builder: (context, state) => const ImportScreen()),
      GoRoute(
        path: '/review',
        builder: (context, state) => ReviewScreen(args: state.extra as ReviewScreenArgs),
      ),
      GoRoute(path: '/categories', builder: (context, state) => const CategoryMemoryScreen()),
    ],
  );
});
