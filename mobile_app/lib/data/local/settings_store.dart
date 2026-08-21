import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret app settings. Anything sensitive (API token, budget/statement
/// passwords) lives in SecretStore instead — see that file's doc comment.
class SettingsStore {
  static const _kBackendUrl = 'backend_url';
  static const _kBudgetSyncId = 'budget_sync_id';
  static const _kBudgetName = 'budget_name';
  static const _kLastAccountId = 'last_account_id';

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

  Future<void> clear() => _prefs.clear();
}
