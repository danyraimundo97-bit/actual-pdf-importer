import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../models/actual_account.dart';
import '../models/actual_budget.dart';
import '../models/account_page.dart';
import '../models/actual_category.dart';
import '../models/actual_connection.dart';
import '../models/budget_month.dart';
import '../models/quick_add.dart';
import '../models/backend_config.dart';
import '../models/dashboard.dart';
import '../models/import_result.dart';
import '../models/parse_result.dart';
import '../models/parsed_transaction.dart';
import 'api_client.dart';

/// What GET /health says about the configured backend URL.
enum HealthStatus { ok, unreachable, notImporter }

/// Shown when the URL answers, but not as the importer — most often because
/// the Actual server's URL was entered instead of the backend's.
const notImporterMessage = 'Something answered at this address, but it is not the importer backend. '
    "If it is your Actual server (port 5006), use the importer backend's address instead "
    '(port 3000 by default).';

/// Wraps the importer backend's endpoints. Every screen calls through
/// here, never `dio` directly — see the plan's "widgets never touch dio
/// directly" rule.
class ImporterApi {
  final ApiClient _client;

  ImporterApi(this._client);

  Dio get _dio => _client.dio;

  /// GET /health. Deliberately swallows errors into a status rather than
  /// throwing — Settings uses this to distinguish "unreachable" from
  /// "reachable but the token was rejected" (which /config would surface).
  ///
  /// Checks the body, not just the 200: a web app such as Actual's own
  /// server answers every path with its HTML page, so a status-only check
  /// would call it healthy when the user typed the wrong URL.
  Future<HealthStatus> health() async {
    try {
      final res = await _dio.get('/health');
      final data = res.data;
      return data is Map && data['status'] == 'ok' ? HealthStatus.ok : HealthStatus.notImporter;
    } on DioException catch (e) {
      return e.response == null ? HealthStatus.unreachable : HealthStatus.notImporter;
    }
  }

  Future<BackendConfig> getConfig() async {
    final res = await _guarded(() => _dio.get('/config'));
    return BackendConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ActualBudget>> getBudgets() async {
    final res = await _guarded(() => _dio.get('/budgets'));
    final list = (res.data['budgets'] as List).cast<Map<String, dynamic>>();
    return list.map(ActualBudget.fromJson).toList();
  }

  Future<List<ActualAccount>> getAccounts({String? budgetSyncId}) async {
    final res = await _guarded(
      () => _dio.get(
        '/accounts',
        queryParameters: {if (budgetSyncId != null) 'budgetSyncId': budgetSyncId},
      ),
    );
    final list = (res.data['accounts'] as List).cast<Map<String, dynamic>>();
    return list.map(ActualAccount.fromJson).toList();
  }

  Future<List<ActualCategoryGroup>> getActualCategories({String? budgetSyncId}) async {
    final res = await _guarded(
      () => _dio.get(
        '/actual/categories',
        queryParameters: {if (budgetSyncId != null) 'budgetSyncId': budgetSyncId},
      ),
    );
    final list = (res.data['groups'] as List).cast<Map<String, dynamic>>();
    return list.map(ActualCategoryGroup.fromJson).toList();
  }

  /// GET /dashboard: aggregated metrics for one budget (see the backend's
  /// src/dashboard.ts for what each number includes).
  Future<Dashboard> getDashboard({String? budgetSyncId, int months = 6}) async {
    final res = await _guarded(
      () => _dio.get(
        '/dashboard',
        queryParameters: {'months': months, if (budgetSyncId != null) 'budgetSyncId': budgetSyncId},
      ),
    );
    return Dashboard.fromJson(res.data as Map<String, dynamic>);
  }

  // --- Actual connection (optional; see the backend's actual-connection.ts) --

  Future<ActualConnection> getActualConnection() async {
    final res = await _guarded(() => _dio.get('/actual/connection'));
    return ActualConnection.fromJson(res.data as Map<String, dynamic>);
  }

  /// Tests the server on the backend (reachable, recent enough, password
  /// accepted) and saves it only if it works. Throws ApiException with
  /// ACTUAL_UNREACHABLE / ACTUAL_AUTH_FAILED / ACTUAL_VERSION_TOO_OLD /
  /// AUTH_REQUIRED / CONNECTION_LOCKED / INVALID_FIELD.
  Future<ActualConnection> connectActual({required String serverUrl, required String password}) async {
    final res = await _guarded(
      () => _dio.put(
        '/actual/connection',
        data: {'serverUrl': serverUrl, 'password': password},
        // The backend probes the server before answering.
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      ),
    );
    return ActualConnection.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ActualConnection> disconnectActual() async {
    final res = await _guarded(() => _dio.delete('/actual/connection'));
    return ActualConnection.fromJson(res.data as Map<String, dynamic>);
  }

  // --- Everyday screens -------------------------------------------------

  Future<QuickAddOptions> getQuickAddOptions({String? budgetSyncId}) async {
    final res = await _guarded(
      () => _dio.get('/quick-add/options', queryParameters: {'budgetSyncId': ?budgetSyncId}),
    );
    return QuickAddOptions.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /transactions. Safe to retry with the same [clientId]: the
  /// backend returns the transaction it already added.
  Future<({String? id, bool created})> addTransaction({
    required String accountId,
    required DateTime date,
    required int amountCents,
    required String clientId,
    String? payeeName,
    String? categoryId,
    String? notes,
    String? budgetSyncId,
    String? budgetPassword,
  }) async {
    final res = await _guarded(
      () => _dio.post(
        '/transactions',
        data: {
          'accountId': accountId,
          'date': date.toIso8601String().substring(0, 10),
          'amountCents': amountCents,
          'clientId': clientId,
          'payeeName': ?payeeName,
          'categoryId': ?categoryId,
          'notes': ?notes,
          'budgetSyncId': ?budgetSyncId,
          'budgetPassword': ?budgetPassword,
        },
      ),
    );
    final data = res.data as Map<String, dynamic>;
    return (id: data['id'] as String?, created: data['created'] as bool? ?? true);
  }

  Future<AccountPage> getAccountPage(String accountId, {String? budgetSyncId, String? before, int limit = 50}) async {
    final res = await _guarded(
      () => _dio.get(
        '/accounts/${Uri.encodeComponent(accountId)}/transactions',
        queryParameters: {'limit': limit, 'budgetSyncId': ?budgetSyncId, 'before': ?before},
      ),
    );
    return AccountPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<BudgetMonth> getBudgetMonth({String? budgetSyncId, String? month}) async {
    final res = await _guarded(
      () => _dio.get('/budget-month', queryParameters: {'budgetSyncId': ?budgetSyncId, 'month': ?month}),
    );
    return BudgetMonth.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /parse. Long timeout override: in PARSER_MODE=ai/both a large
  /// statement can genuinely take close to a minute.
  Future<ParseResult> parseStatement({
    required Uint8List bytes,
    required String filename,
    String? password,
    String? budgetSyncId,
  }) async {
    final form = FormData.fromMap({
      'statement': MultipartFile.fromBytes(bytes, filename: filename),
      if (password != null && password.isNotEmpty) 'password': password,
      if (budgetSyncId != null) 'budgetSyncId': budgetSyncId,
    });
    final res = await _guarded(
      () => _dio.post(
        '/parse',
        data: form,
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      ),
    );
    return ParseResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /import/confirm. Only transactions the caller wants imported
  /// should be passed here — filter out excluded rows before calling.
  Future<ImportResult> confirmImport({
    required String accountId,
    required List<ParsedTransaction> transactions,
    String? budgetSyncId,
    String? budgetPassword,
  }) async {
    final res = await _guarded(
      () => _dio.post(
        '/import/confirm',
        data: {
          'accountId': accountId,
          'transactions': transactions.map((t) => t.toConfirmJson()).toList(),
          if (budgetSyncId != null) 'budgetSyncId': budgetSyncId,
          if (budgetPassword != null) 'budgetPassword': budgetPassword,
        },
      ),
    );
    return ImportResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// Maps Dio failures to [ApiException], and rejects a reply that isn't a
  /// JSON object: every importer route answers with one, so anything else
  /// (typically an HTML page) means the URL points at some other server.
  /// POST /import/undo: soft-deletes the transactions one import added —
  /// in Actual they become 0.00 with a "removed" note, nothing is deleted.
  /// Only ones the importer created are touched (see the backend).
  Future<({int removed, int skipped})> undoImport({
    required String accountId,
    required List<String> transactionIds,
    String? budgetSyncId,
    String? budgetPassword,
  }) async {
    final res = await _guarded(
      () => _dio.post(
        '/import/undo',
        data: {
          'accountId': accountId,
          'transactionIds': transactionIds,
          if (budgetSyncId != null) 'budgetSyncId': budgetSyncId,
          if (budgetPassword != null) 'budgetPassword': budgetPassword,
        },
      ),
    );
    final data = res.data as Map<String, dynamic>;
    return (removed: data['removed'] as int, skipped: data['skipped'] as int);
  }

  /// GET /logs: the backend's most recent log lines, as text, for a log
  /// report. Null if the backend can't provide them (unreachable, an older
  /// backend without the route, or auth disabled there): a report must
  /// still be shareable without them.
  Future<String?> getBackendLogs({int tail = 500}) async {
    try {
      final res = await _dio.get('/logs', queryParameters: {'tail': tail});
      final lines = res.data is Map ? res.data['lines'] : null;
      return lines is List ? lines.join('\n') : null;
    } on DioException {
      return null;
    }
  }

  Future<Response<dynamic>> _guarded(Future<Response<dynamic>> Function() call) async {
    final Response<dynamic> res;
    try {
      res = await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    if (res.data is! Map) {
      throw ApiException(statusCode: res.statusCode, message: notImporterMessage);
    }
    return res;
  }
}
