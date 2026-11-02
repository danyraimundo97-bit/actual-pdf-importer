import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/log/app_log.dart';
import 'core/log/error_hooks.dart';
import 'core/log/log_file_store.dart';
import 'core/log/sinks.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/settings_store.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  Logs.init(
    sinks: [if (kDebugMode) ConsoleSink()],
    fileStore: await openLogFileStore(),
    debugEnabled: SettingsStore(prefs).debugLogging,
  );
  installGlobalErrorHandlers();
  // Flush buffered log lines when the app goes to the background, where the
  // OS may kill it without warning. The binding keeps the listener alive.
  AppLifecycleListener(onPause: Logs.flush, onDetach: Logs.flush);
  logAppStart();

  runApp(
    ProviderScope(
      observers: const [LogProviderObserver()],
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ImporterApp(),
    ),
  );
}

class ImporterApp extends ConsumerWidget {
  const ImporterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Actual PDF Importer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
