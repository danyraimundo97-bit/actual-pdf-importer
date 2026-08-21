import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../models/category_mapping.dart';
import 'api_client.dart';

/// Wraps the local category-memory endpoints (/categories) — not to be
/// confused with ImporterApi.getActualCategories, which reads Actual's
/// own categories. This is the payee -> category memory in categorydb.ts.
class CategoriesApi {
  final ApiClient _client;

  CategoriesApi(this._client);

  Dio get _dio => _client.dio;

  Future<List<CategoryMapping>> list({String? budgetSyncId}) async {
    final res = await _guarded(
      () => _dio.get(
        '/categories',
        queryParameters: {if (budgetSyncId != null) 'budgetSyncId': budgetSyncId},
      ),
    );
    final list = (res.data['mappings'] as List).cast<Map<String, dynamic>>();
    return list.map(CategoryMapping.fromJson).toList();
  }

  Future<void> upsert({
    required String payee,
    required String categoryId,
    String? categoryName,
    String? budgetSyncId,
  }) async {
    await _guarded(
      () => _dio.post(
        '/categories',
        data: {
          'payee': payee,
          'categoryId': categoryId,
          if (categoryName != null) 'categoryName': categoryName,
          if (budgetSyncId != null) 'budgetSyncId': budgetSyncId,
        },
      ),
    );
  }

  Future<void> delete(String payee, {String? budgetSyncId}) async {
    await _guarded(
      () => _dio.delete(
        '/categories/${Uri.encodeComponent(payee)}',
        queryParameters: {if (budgetSyncId != null) 'budgetSyncId': budgetSyncId},
      ),
    );
  }

  Future<({int learned, int scanned})> learnFromActual({
    required String accountId,
    required String startDate,
    required String endDate,
    String? budgetSyncId,
    String? budgetPassword,
  }) async {
    final res = await _guarded(
      () => _dio.post(
        '/categories/learn-from-actual',
        data: {
          'accountId': accountId,
          'startDate': startDate,
          'endDate': endDate,
          if (budgetSyncId != null) 'budgetSyncId': budgetSyncId,
          if (budgetPassword != null) 'budgetPassword': budgetPassword,
        },
      ),
    );
    final data = res.data as Map<String, dynamic>;
    return (learned: data['learned'] as int, scanned: data['scanned'] as int);
  }

  Future<Response<dynamic>> _guarded(Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
