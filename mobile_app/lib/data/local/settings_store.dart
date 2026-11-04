import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret app settings. Anything sensitive (API token, budget/statement
/// passwords) lives in SecretStore instead — see that file's doc comment.
class SettingsStore {
  static const _kBackendUrl = 'backend_url';
  static const _kBudgetSyncId = 'budget_sync_id';
  static const _kBudgetName = 'budget_name';
  static const _kLastAccountId = 'last_account_id';
  static const _kOnboarded = 'onboarded';
  static const _kDebugLogging = 'debug_logging';
  static const _kParseOnDevice = 'parse_on_device';
  static const _kSkippedMatchesPrefix = 'category_match_skipped:';
  static const _kSyncCursorPrefix = 'category_sync_cursor:';
  static const _kSyncWatermarkPrefix = 'category_sync_watermark:';
  static const _kDatabaseWasReset = 'database_was_reset';

  final SharedPreferences _prefs;

  const SettingsStore(this._prefs);

  String? get backendUrl => _prefs.getString(_kBackendUrl);
  Future<void> setBackendUrl(String url) => _prefs.setString(_kBackendUrl, url);

  String? get budgetSyncId => _prefs.getString(_kBudgetSyncId);
  Future<void> setBudgetSyncId(String id) => _prefs.setString(_kBudgetSyncId, id);

  String? get budgetName => _prefs.getString(_kBudgetName);
  Future<void> setBudgetName(String name) => _prefs.setString(_kBudgetName, name);

  String? get lastAccountId => _prefs.getString(_kLastAccountId);
  Future<void> setLastAccountId(String id) => _prefs.setString(_kLastAccountId, id);

  /// Null for installs from before the setup guide existed; AppConfig
  /// derives a value from the connection settings in that case.
  bool? get onboarded => _prefs.getBool(_kOnboarded);
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);

  /// The user's "Verbose logging" choice; null = the build's default
  /// (`--dart-define=LOG_DEBUG`).
  bool? get debugLogging => _prefs.getBool(_kDebugLogging);
  Future<void> setDebugLogging(bool value) => _prefs.setBool(_kDebugLogging, value);

  /// Read statements on the phone (default) instead of uploading them to
  /// the backend's parser. Off is the fallback for a bank whose layout
  /// changed before the app's parsers caught up.
  bool get parseOnDevice => _prefs.getBool(_kParseOnDevice) ?? true;
  Future<void> setParseOnDevice(bool value) => _prefs.setBool(_kParseOnDevice, value);

  /// Local categories the user chose not to match to [budgetSyncId]'s
  /// Actual categories, so "Match your categories" stops asking about them.
  Set<String> skippedCategoryMatches(String budgetSyncId) =>
      (_prefs.getStringList('$_kSkippedMatchesPrefix$budgetSyncId') ?? const []).toSet();
  Future<void> setSkippedCategoryMatches(String budgetSyncId, Set<String> ids) =>
      _prefs.setStringList('$_kSkippedMatchesPrefix$budgetSyncId', ids.toList()..sort());

  /// Category sync bookkeeping, per budget ('' = none): the backend's `now`
  /// from the last sync (its clock), and when that sync started on the phone
  /// (the phone's clock: rows edited after it are sent next time).
  int? categorySyncCursor(String budgetKey) => _prefs.getInt('$_kSyncCursorPrefix$budgetKey');
  int? categorySyncWatermark(String budgetKey) => _prefs.getInt('$_kSyncWatermarkPrefix$budgetKey');
  Future<void> setCategorySync(String budgetKey, {required int cursor, required int watermark}) async {
    await _prefs.setInt('$_kSyncCursorPrefix$budgetKey', cursor);
    await _prefs.setInt('$_kSyncWatermarkPrefix$budgetKey', watermark);
  }

  /// Forgets every budget's category sync position, so the next sync
  /// brings everything back from the backend (after the database was reset).
  Future<void> clearCategorySync() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_kSyncCursorPrefix) || key.startsWith(_kSyncWatermarkPrefix)) await _prefs.remove(key);
    }
  }

  /// Set when the database couldn't be opened with its key and the app
  /// started with an empty one; cleared once the user has been told.
  bool get databaseWasReset => _prefs.getBool(_kDatabaseWasReset) ?? false;
  Future<void> setDatabaseWasReset(bool value) => _prefs.setBool(_kDatabaseWasReset, value);

  Future<void> clear() => _prefs.clear();
}
