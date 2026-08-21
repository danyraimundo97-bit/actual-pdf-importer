import 'package:dio/dio.dart';

import '../local/secret_store.dart';

/// One Dio instance per backend URL — see providers.dart's apiClientProvider,
/// which rebuilds this whenever the configured URL changes rather than
/// mutating baseUrl in place.
class ApiClient {
  final Dio dio;

  ApiClient({required String baseUrl, required SecretStore secretStore})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secretStore.apiToken;
          if (token != null && token.isNotEmpty) {
            options.headers['X-Import-Token'] = token;
          }
          handler.next(options);
        },
      ),
    );
  }
}
