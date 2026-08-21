import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../models/actual_account.dart';
import '../models/actual_budget.dart';
import '../models/actual_category.dart';
import '../models/backend_config.dart';
import '../models/import_result.dart';
import '../models/parse_result.dart';
import '../models/parsed_transaction.dart';
import 'api_client.dart';

/// Wraps the importer backend's endpoints. Every screen calls through
/// here, never `dio` directly — see the plan's "widgets never touch dio
/// directly" rule.
class ImporterApi {
  final ApiClient _client;

  ImporterApi(this._client);

  Dio get _dio => _client.dio;

  /// GET /health. Deliberately swallows errors into `false` rather than
  /// throwing — Settings uses this to distinguish "unreachable" from
  /// "reachable but the token was rejected" (which /config would surface).
  Future<bool> health() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } on DioException {
      return false;
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

  Future<Response<dynamic>> _guarded(Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
