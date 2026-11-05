import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import 'api_client.dart';

/// The backend's ledger routes (docs/plans/local-ledger.md, Phase 5;
/// backend_app/src/ledger.ts). The response is gzipped; Dio's HTTP client
/// asks for and unpacks that by itself.
class LedgerApi {
  final ApiClient _client;

  LedgerApi(this._client);

  Dio get _dio => _client.dio;

  /// GET /ledger/pull: what changed in the budget since the cursor, or
  /// everything when the cursor is null or from another epoch.
  Future<Map<String, dynamic>> pull({required String budgetSyncId, String? epoch, int? lastId}) async {
    try {
      final res = await _dio.get(
        '/ledger/pull',
        queryParameters: {'budgetSyncId': budgetSyncId, 'epoch': ?epoch, 'lastId': ?lastId},
        // A full pull of a large budget takes a few seconds on a slow link.
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /ledger/push: outbox entries, answered one by one.
  Future<List<Map<String, dynamic>>> push({
    required String budgetSyncId,
    String? budgetPassword,
    required List<Map<String, dynamic>> entries,
  }) async {
    try {
      final res = await _dio.post(
        '/ledger/push',
        data: {'budgetSyncId': budgetSyncId, 'budgetPassword': ?budgetPassword, 'entries': entries},
        // A long statement is a few hundred rows for Actual to take in.
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return ((res.data as Map<String, dynamic>)['results'] as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
