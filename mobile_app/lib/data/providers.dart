import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/categories_api.dart';
import 'api/importer_api.dart';
import 'local/import_history_store.dart';
import 'local/secret_store.dart';
import 'local/settings_store.dart';
import 'models/backend_config.dart';
import 'models/budget_month.dart';
import 'models/dashboard.dart';
import 'pdf/local_statement_reader.dart';
import 'pdf/pdf_text_extractor.dart';

/// Overridden in main() with the real instance obtained via
/// SharedPreferences.getInstance() before runApp — reading this before
/// that override is a programming error, hence the throw.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return SettingsStore(ref.watch(sharedPreferencesProvider));
});

final secretStoreProvider = Provider<SecretStore>((ref) {
  return SecretStore(ref.watch(secureStorageProvider));
});

/// The subset of settings that affect which backend/budget every screen
/// talks to. Kept together (rather than as separate StateProviders) so a
/// budget switch always updates syncId and name atomically.
class AppConfig {
  final String? backendUrl;
  final String? budgetSyncId;
  final String? budgetName;

  /// Whether the welcome + setup flow has been completed. Gates every
  /// route except the onboarding ones (see core/router.dart).
  final bool onboarded;

  const AppConfig({this.backendUrl, this.budgetSyncId, this.budgetName, this.onboarded = false});

  AppConfig copyWith({
    String? backendUrl,
    String? budgetSyncId,
    String? budgetName,
    bool? onboarded,
  }) {
    return AppConfig(
      backendUrl: backendUrl ?? this.backendUrl,
      budgetSyncId: budgetSyncId ?? this.budgetSyncId,
      budgetName: budgetName ?? this.budgetName,
      onboarded: onboarded ?? this.onboarded,
    );
  }
}

class AppConfigController extends StateNotifier<AppConfig> {
  final SettingsStore _store;

  AppConfigController(this._store)
    : super(
        AppConfig(
          backendUrl: _store.backendUrl,
          budgetSyncId: _store.budgetSyncId,
          budgetName: _store.budgetName,
          // Installs from before the setup guide existed have no flag;
          // if they are already connected to a budget, don't send them
          // through the welcome screen again.
          onboarded:
              _store.onboarded ??
              ((_store.backendUrl?.isNotEmpty ?? false) && _store.budgetSyncId != null),
        ),
      );

  Future<void> setBackendUrl(String url) async {
    await _store.setBackendUrl(url);
    state = state.copyWith(backendUrl: url);
  }

  Future<void> setBudget(String syncId, String name) async {
    await _store.setBudgetSyncId(syncId);
    await _store.setBudgetName(name);
    state = state.copyWith(budgetSyncId: syncId, budgetName: name);
  }

  Future<void> setOnboarded(bool value) async {
    await _store.setOnboarded(value);
    state = state.copyWith(onboarded: value);
  }

  /// Forgets every non-secret setting (dev page "wipe everything").
  Future<void> reset() async {
    await _store.clear();
    state = const AppConfig();
  }
}

final appConfigProvider = StateNotifierProvider<AppConfigController, AppConfig>((ref) {
  return AppConfigController(ref.watch(settingsStoreProvider));
});

/// Rebuilds (and creates a fresh Dio instance) whenever the configured
/// backend URL changes — see ApiClient's doc comment for why that's
/// simpler than mutating baseUrl on a shared instance.
final apiClientProvider = Provider<ApiClient>((ref) {
  final backendUrl = ref.watch(appConfigProvider).backendUrl;
  return ApiClient(baseUrl: backendUrl ?? '', secretStore: ref.watch(secretStoreProvider));
});

final importerApiProvider = Provider<ImporterApi>((ref) {
  return ImporterApi(ref.watch(apiClientProvider));
});

/// On-device PDF reading (docs/plans/dart-parser.md, Phase 3). Tests
/// override [pdfTextExtractorProvider] with a fake.
final pdfTextExtractorProvider = Provider<PdfTextExtractor>((ref) => PdfrxTextExtractor());

/// Settings → "Read statements on this phone". Change it through
/// [setParseOnDevice] so the stored value and the screens stay in step.
final parseOnDeviceProvider = StateProvider<bool>((ref) => ref.watch(settingsStoreProvider).parseOnDevice);

Future<void> setParseOnDevice(WidgetRef ref, bool value) async {
  await ref.read(settingsStoreProvider).setParseOnDevice(value);
  ref.read(parseOnDeviceProvider.notifier).state = value;
}

final localStatementReaderProvider = Provider<LocalStatementReader>((ref) {
  return LocalStatementReader(ref.watch(pdfTextExtractorProvider));
});

final categoriesApiProvider = Provider<CategoriesApi>((ref) {
  return CategoriesApi(ref.watch(apiClientProvider));
});

/// GET /config, refetched whenever the backend changes. Used for the
/// Import screen's privacy banner and Settings' connection status.
final backendConfigProvider = FutureProvider.autoDispose<BackendConfig>((ref) {
  return ref.watch(importerApiProvider).getConfig();
});

/// How far the app is connected: the backend and Actual are both optional
/// (docs/plans/core-app.md), so screens that need Actual check this and show
/// the shared "connect" state instead of an error.
enum LinkState {
  /// No backend address set.
  noBackend,

  /// The backend answers but has no Actual server.
  noActual,

  /// Actual is connected but no budget is chosen yet.
  noBudget,

  /// Everything needed for Actual screens.
  ready,
}

final linkStateProvider = FutureProvider.autoDispose<LinkState>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (config.backendUrl == null || config.backendUrl!.isEmpty) return LinkState.noBackend;
  final backend = await ref.watch(backendConfigProvider.future);
  if (!backend.actualConfigured) return LinkState.noActual;
  if (config.budgetSyncId == null) return LinkState.noBudget;
  return LinkState.ready;
});

/// Bumped whenever the backend's payee→category memory may have changed
/// behind the Memory tab's back — an import saves the categories used. The
/// tab stays alive in the shell, so it listens to this to reload.
final categoryMemoryRevisionProvider = StateProvider<int>((ref) => 0);

/// GET /dashboard for the active budget. Invalidated after an import so
/// the numbers reflect what was just added.
final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  final budgetSyncId = ref.watch(appConfigProvider.select((c) => c.budgetSyncId));
  return ref.watch(importerApiProvider).getDashboard(budgetSyncId: budgetSyncId);
});

/// GET /budget-month for the active budget; `null` = the current month.
/// Invalidated after a quick add or an import.
final budgetMonthProvider = FutureProvider.autoDispose.family<BudgetMonth, String?>((ref, month) {
  final budgetSyncId = ref.watch(appConfigProvider.select((c) => c.budgetSyncId));
  return ref.watch(importerApiProvider).getBudgetMonth(budgetSyncId: budgetSyncId, month: month);
});

final importHistoryStoreProvider = Provider<ImportHistoryStore>((ref) {
  return ImportHistoryStore(ref.watch(sharedPreferencesProvider));
});

final importHistoryProvider =
    StateNotifierProvider<ImportHistoryController, List<ImportHistoryEntry>>((ref) {
      return ImportHistoryController(ref.watch(importHistoryStoreProvider));
    });
