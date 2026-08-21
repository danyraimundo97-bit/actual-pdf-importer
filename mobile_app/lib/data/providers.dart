import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/categories_api.dart';
import 'api/importer_api.dart';
import 'local/secret_store.dart';
import 'local/settings_store.dart';
import 'models/backend_config.dart';

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

  const AppConfig({this.backendUrl, this.budgetSyncId, this.budgetName});

  AppConfig copyWith({String? backendUrl, String? budgetSyncId, String? budgetName}) {
    return AppConfig(
      backendUrl: backendUrl ?? this.backendUrl,
      budgetSyncId: budgetSyncId ?? this.budgetSyncId,
      budgetName: budgetName ?? this.budgetName,
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
