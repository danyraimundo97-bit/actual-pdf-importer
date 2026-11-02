/// What may reach a log, enforced by field name rather than by convention.
/// Mirrors the backend's rules (docs/plans/logging.md, "Personal banking
/// data"):
///
/// - secrets (tokens, passwords, keys): never, at any level;
/// - amounts and balances: never, at any level;
/// - `rawLine`: never, because a statement line carries its amount;
/// - payees and descriptions: only when the debug flag is on;
/// - ids, dates, bank ids, counts: always allowed.
library;

const redacted = '<redacted>';

const _secretKeys = {
  'token',
  'apitoken',
  'importtoken',
  'x-import-token',
  'authorization',
  'password',
  'budgetpassword',
  'statementpassword',
  'serverpassword',
  'apikey',
  'secret',
};

const _alwaysDropped = {'rawline', 'pdf', 'bytes', 'text', 'pdftext'};

const _debugOnly = {'payee', 'payeekey', 'payeename', 'payeelabel', 'description', 'importedpayee'};

String _norm(String key) => key.toLowerCase().replaceAll('_', '');

bool _isSecret(String key) {
  final k = _norm(key);
  return _secretKeys.contains(k) || k.endsWith('password') || k.endsWith('token') || k.endsWith('apikey');
}

bool _isMoney(String key) {
  final k = _norm(key);
  return k == 'amount' || k.startsWith('amount') || k.startsWith('balance') || k.endsWith('cents');
}

/// Returns a copy of [fields] that is safe to write. Secrets become
/// [redacted] (so a reader sees one was present), money and raw lines are
/// removed, payees are removed unless [debugEnabled]. Nested maps are
/// cleaned the same way.
Map<String, Object?> redactFields(Map<String, Object?> fields, {required bool debugEnabled}) {
  final out = <String, Object?>{};
  fields.forEach((key, value) {
    final k = _norm(key);
    if (_isSecret(key)) {
      out[key] = redacted;
    } else if (_isMoney(key) || _alwaysDropped.contains(k)) {
      return;
    } else if (_debugOnly.contains(k) && !debugEnabled) {
      return;
    } else if (value is Map) {
      out[key] = redactFields(value.cast<String, Object?>(), debugEnabled: debugEnabled);
    } else {
      out[key] = value;
    }
  });
  return out;
}

/// Query parameters as they may be logged: values of secret keys replaced.
Map<String, Object?> redactQuery(Map<String, dynamic> query, {required bool debugEnabled}) =>
    redactFields(query.cast<String, Object?>(), debugEnabled: debugEnabled);
