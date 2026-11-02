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

  Future<void> clear() => _prefs.clear();
}
