import 'package:dio/dio.dart';

import '../../core/log/http_log_interceptor.dart';
import '../local/secret_store.dart';

/// Turns what the user typed into a base URL Dio accepts on every platform,
/// or null when it can't be one. A missing scheme gets `http://` — the
/// backend is plain HTTP on the LAN — since Dio rejects scheme-less URLs
/// everywhere except web, where they slip through as relative paths.
String? normalizeBackendUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return null;
  if (!url.contains('://')) url = 'http://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return url;
}

/// One Dio instance per backend URL — see providers.dart's apiClientProvider,
/// which rebuilds this whenever the configured URL changes rather than
/// mutating baseUrl in place.
class ApiClient {
  final Dio dio;

  ApiClient({required String baseUrl, required SecretStore secretStore})
      : dio = Dio(
          BaseOptions(
            // Normalized here too, so an address saved before validation
            // existed (e.g. "localhost:3000") can't crash the app at startup.
            baseUrl: normalizeBackendUrl(baseUrl) ?? '',
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
    // After the token interceptor, but it never logs headers either way.
    dio.interceptors.add(HttpLogInterceptor());
  }
}
