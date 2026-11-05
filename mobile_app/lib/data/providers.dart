import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/backups_api.dart';
import 'api/categories_api.dart';
import 'api/importer_api.dart';
import 'api/ledger_api.dart';
import 'local/db/app_database.dart';
import 'local/db/database_opening.dart';
import 'local/db/local_category_store.dart';
import 'local/db/open_connection.dart';
import 'local/import_history_store.dart';
import 'local/ledger_reports.dart';
import 'local/ledger_builders.dart';
import 'local/ledger_store.dart';
import 'ledger_sync_controller.dart';
import 'local/secret_store.dart';
import 'local/settings_store.dart';
import 'models/backend_config.dart';
import 'models/account_page.dart';
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

/// The app's own database (categories, category memory), encrypted with a
/// key from [SecretStore]. One per app run; tests override it with
/// `AppDatabase(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final settings = ref.watch(settingsStoreProvider);
  final db = AppDatabase(
    openAppDatabaseConnection(
      key: ref.watch(secretStoreProvider).databaseKey,
      onOpened: (outcome) async {
        if (outcome != DatabaseOpening.reset) return;
        // Started empty: the backend's copy (if any) comes back with the
        // next category sync, from the start.
        await settings.clearCategorySync();
        await settings.setDatabaseWasReset(true);
        ref.read(databaseWasResetProvider.notifier).state = true;
      },
    ),
  );
  ref.onDispose(db.close);
  return db;
});

/// True once the database couldn't be opened with its key and the app
/// started with an empty one, until the user has been told (AppShell).
final databaseWasResetProvider = StateProvider<bool>((ref) => ref.watch(settingsStoreProvider).databaseWasReset);

final localCategoryStoreProvider = Provider<LocalCategoryStore>((ref) {
  return LocalCategoryStore(ref.watch(appDatabaseProvider));
});

/// The local ledger (docs/plans/local-ledger.md).
final ledgerStoreProvider = Provider<LedgerStore>((ref) => LedgerStore(ref.watch(appDatabaseProvider)));

/// The phone's own accounts with their balances, live. (The scope of a
/// budget synced with Actual comes with Phase 5.)
final ledgerAccountsProvider = StreamProvider.autoDispose<List<LedgerAccountView>>((ref) {
  return ref.watch(ledgerStoreProvider).watchAccounts(phoneScope);
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

final backupsApiProvider = Provider<BackupsApi>((ref) {
  return BackupsApi(ref.watch(apiClientProvider));
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

/// Whose ledger Home, Budget and the account screen show
/// (docs/plans/local-ledger.md, Phases 4 and 5): the connected Actual
/// budget's copy (scope = its sync id), or the phone's own budget
/// ([phoneScope]) without Actual.
///
/// A backend that can't be reached says nothing about Actual: a budget with
/// a copy on the phone stays shown, and its changes wait.
final ledgerScopeProvider = FutureProvider.autoDispose<String>((ref) async {
  final budgetSyncId = ref.watch(appConfigProvider.select((c) => c.budgetSyncId));
  try {
    if (await ref.watch(linkStateProvider.future) != LinkState.ready) return phoneScope;
    return budgetSyncId ?? phoneScope;
  } catch (_) {
    if (budgetSyncId == null) return phoneScope;
    return await ref.read(ledgerStoreProvider).hasPulled(budgetSyncId) ? budgetSyncId : phoneScope;
  }
});

/// True while the screens show the phone's own budget rather than a copy of
/// an Actual one. Both are edited on the phone; only the wording differs.
final readsLedgerProvider = FutureProvider.autoDispose<bool>((ref) async {
  return await ref.watch(ledgerScopeProvider.future) == phoneScope;
});

/// The changes waiting to go to Actual for the budget on screen.
final ledgerOutboxProvider = StreamProvider.autoDispose<({int waiting, int failed})>((ref) async* {
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope == phoneScope) {
    yield (waiting: 0, failed: 0);
    return;
  }
  yield* ref.watch(ledgerStoreProvider).watchOutboxSummary(scope);
});

/// How many of the phone's own accounts could go into the budget on screen;
/// 0 while the screens show the phone's own budget.
final phoneAccountsToMoveProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(ledgerChangesProvider);
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope == phoneScope) return 0;
  return (await ref.read(ledgerStoreProvider).accounts(phoneScope)).length;
});

final ledgerApiProvider = Provider<LedgerApi>((ref) => LedgerApi(ref.watch(apiClientProvider)));

final ledgerReportsProvider = Provider<LedgerReports>((ref) {
  return LedgerReports(ref.watch(appDatabaseProvider), ref.watch(ledgerStoreProvider));
});

/// Counts ledger changes, so what's built from the ledger rebuilds live.
final ledgerChangesProvider = StreamProvider.autoDispose<int>((ref) {
  var changes = 0;
  return ref.watch(ledgerStoreProvider).watchChanges().map((_) => ++changes);
});

/// Home, from the ledger. An Actual budget is pulled once before its copy
/// is shown, so an empty copy never reads as an empty budget.
final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) async {
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope != phoneScope) await ref.read(ledgerSyncProvider.notifier).ensurePulled(scope);
  ref.watch(ledgerChangesProvider);
  return ref.watch(ledgerReportsProvider).dashboard(scope);
});

/// What Home's "without a category" line counts.
final uncategorizedProvider = FutureProvider.autoDispose<List<UncategorizedTransaction>>((ref) async {
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope != phoneScope) await ref.read(ledgerSyncProvider.notifier).ensurePulled(scope);
  ref.watch(ledgerChangesProvider);
  return ref.watch(ledgerReportsProvider).uncategorized(scope);
});

/// Every transaction of one month (`YYYY-MM`), from the ledger.
final monthTransactionsProvider = FutureProvider.autoDispose.family<MonthTransactions, String>((ref, month) async {
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope != phoneScope) await ref.read(ledgerSyncProvider.notifier).ensurePulled(scope);
  ref.watch(ledgerChangesProvider);
  return ref.watch(ledgerReportsProvider).monthTransactions(scope, month);
});

/// The style of the budget on screen: the phone's own choice, or what the last
/// pull said about Actual's.
final budgetStyleProvider = FutureProvider.autoDispose<BudgetStyle>((ref) async {
  ref.watch(ledgerSyncProvider.select((s) => s.lastPulledAt));
  final scope = await ref.watch(ledgerScopeProvider.future);
  return BudgetStyle.parse(await ref.read(ledgerStoreProvider).budgetMode(scope));
});

/// The phone's own budget's style, whatever is on screen.
final phoneBudgetStyleProvider = FutureProvider.autoDispose<BudgetStyle>((ref) async {
  return BudgetStyle.parse(await ref.read(ledgerStoreProvider).budgetMode(phoneScope));
});

/// Budget for one month (`null` = the current one), from the ledger.
final budgetMonthProvider = FutureProvider.autoDispose.family<BudgetMonth, String?>((ref, month) async {
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope != phoneScope) await ref.read(ledgerSyncProvider.notifier).ensurePulled(scope);
  ref.watch(ledgerChangesProvider);
  return ref.watch(ledgerReportsProvider).budgetMonth(scope, month);
});

final importHistoryStoreProvider = Provider<ImportHistoryStore>((ref) {
  return ImportHistoryStore(ref.watch(sharedPreferencesProvider));
});

final importHistoryProvider =
    StateNotifierProvider<ImportHistoryController, List<ImportHistoryEntry>>((ref) {
      return ImportHistoryController(ref.watch(importHistoryStoreProvider));
    });
