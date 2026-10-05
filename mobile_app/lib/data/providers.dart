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
import 'models/dashboard.dart';

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

final categoriesApiProvider = Provider<CategoriesApi>((ref) {
  return CategoriesApi(ref.watch(apiClientProvider));
});

/// GET /config, refetched whenever the backend changes. Used for the
/// Import screen's privacy banner and Settings' connection status.
final backendConfigProvider = FutureProvider.autoDispose<BackendConfig>((ref) {
  return ref.watch(importerApiProvider).getConfig();
});

/// GET /dashboard for the active budget. Invalidated after an import so
/// the numbers reflect what was just added.
final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  final budgetSyncId = ref.watch(appConfigProvider.select((c) => c.budgetSyncId));
  return ref.watch(importerApiProvider).getDashboard(budgetSyncId: budgetSyncId);
});

final importHistoryStoreProvider = Provider<ImportHistoryStore>((ref) {
  return ImportHistoryStore(ref.watch(sharedPreferencesProvider));
});

final importHistoryProvider =
    StateNotifierProvider<ImportHistoryController, List<ImportHistoryEntry>>((ref) {
      return ImportHistoryController(ref.watch(importHistoryStoreProvider));
    });
