import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Anything that must never sit in plain shared_preferences: the API
/// token, per-budget end-to-end-encryption passwords, and (optionally)
/// remembered statement PDF passwords. See SettingsStore for everything
/// else.
class SecretStore {
  static const _kApiToken = 'api_token';
  static const _kBudgetPasswordPrefix = 'budget_password_'; // + syncId
  static const _kPdfPasswordPrefix = 'pdf_password_'; // + bankId

  final FlutterSecureStorage _storage;

  const SecretStore(this._storage);

  Future<String?> get apiToken => _storage.read(key: _kApiToken);
  Future<void> setApiToken(String token) => _storage.write(key: _kApiToken, value: token);
  Future<void> clearApiToken() => _storage.delete(key: _kApiToken);

  Future<String?> budgetPassword(String syncId) =>
      _storage.read(key: '$_kBudgetPasswordPrefix$syncId');
  Future<void> setBudgetPassword(String syncId, String password) =>
      _storage.write(key: '$_kBudgetPasswordPrefix$syncId', value: password);

  Future<String?> pdfPassword(String bankId) => _storage.read(key: '$_kPdfPasswordPrefix$bankId');
  Future<void> setPdfPassword(String bankId, String password) =>
      _storage.write(key: '$_kPdfPasswordPrefix$bankId', value: password);

  Future<void> forgetAllPdfPasswords() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_kPdfPasswordPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }
}
