import 'dart:math';

import 'package:dio/dio.dart';

import 'app_log.dart';
import 'redaction.dart';

const requestIdHeader = 'X-Request-Id';

const _log = AppLog('http');
const _startKey = 'log.start';
const _idKey = 'log.requestId';

final _random = Random.secure();

/// 16 hex chars: enough to find one request in both logs.
String newRequestId() => List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// Logs every backend request and gives it an `X-Request-Id`, which the
/// backend logs too, so a failure seen on the phone can be found in the
/// backend's log.
///
/// - info: method, path (never the query string), status, duration, id;
/// - warn: a failed request, with the backend's error `code` or the
///   network failure type;
/// - debug: the query parameters, with secrets redacted.
///
/// Never logs headers (the token is one) or bodies (PDFs, transactions).
class HttpLogInterceptor extends Interceptor {
  final DateTime Function() _now;

  HttpLogInterceptor({DateTime Function()? now}) : _now = now ?? DateTime.now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = newRequestId();
    options.headers[requestIdHeader] = id;
    options.extra[_idKey] = id;
    options.extra[_startKey] = _now();
    if (options.queryParameters.isNotEmpty) {
      _log.debug('${options.method} ${options.uri.path} query', {
        'req': id,
        'query': redactQuery(options.queryParameters, debugEnabled: Logs.debugEnabled),
      });
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    _log.info('${o.method} ${o.uri.path} ${response.statusCode} ${_ms(o)}ms', {'req': o.extra[_idKey]});
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final response = err.response;
    final data = response?.data;
    final code = data is Map ? data['code'] : null;
    _log.warn('${o.method} ${o.uri.path} ${response?.statusCode ?? 'failed'} ${_ms(o)}ms', {
      'req': o.extra[_idKey],
      'code': ?code,
      if (response == null) 'type': err.type.name,
    });
    handler.next(err);
  }

  int _ms(RequestOptions o) {
    final start = o.extra[_startKey];
    return start is DateTime ? _now().difference(start).inMilliseconds : -1;
  }
}
