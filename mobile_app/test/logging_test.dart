import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/log/app_log.dart';
import 'package:mobile_app/core/log/http_log_interceptor.dart';
import 'package:mobile_app/core/log/log_entry.dart';
import 'package:mobile_app/core/log/log_file_store.dart';
import 'package:mobile_app/core/log/log_file_store_io.dart';
import 'package:mobile_app/core/log/redaction.dart';
import 'package:mobile_app/features/diagnostics/log_report.dart';

const _log = AppLog('test');

/// Answers every request with [status] and [body], remembering the headers.
class _FakeAdapter implements HttpClientAdapter {
  final int status;
  final Object body;
  Map<String, dynamic>? lastHeaders;

  _FakeAdapter(this.status, this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = options.headers;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _allText() => Logs.memory.entries.map((e) => e.toLine()).join('\n');

void main() {
  setUp(() => Logs.resetForTest());

  group('redaction', () {
    test('secrets are replaced at every level, even with debug on', () {
      final out = redactFields({
        'token': 'abc',
        'X-Import-Token': 'abc',
        'budgetPassword': 'p',
        'serverPassword': 'p',
        'apiKey': 'k',
        'req': 'r1',
      }, debugEnabled: true);
      expect(out, {
        'token': redacted,
        'X-Import-Token': redacted,
        'budgetPassword': redacted,
        'serverPassword': redacted,
        'apiKey': redacted,
        'req': 'r1',
      });
    });

    test('amounts, balances and raw lines are dropped at every level', () {
      for (final debug in [false, true]) {
        final out = redactFields({
          'amount': -450,
          'amountCents': -450,
          'balanceCents': 1000,
          'netWorthCents': 5,
          'rawLine': '01-07-2026 COMPRA 2,60',
          'importedId': 'pdfimport-1',
        }, debugEnabled: debug);
        expect(out, {'importedId': 'pdfimport-1'}, reason: 'debug=$debug');
      }
    });

    test('payees only with debug on; ids and dates always', () {
      final fields = {'payee': 'CONTINENTE', 'payeeKey': 'continente', 'date': '2026-07-01', 'categoryId': 'c1'};
      expect(redactFields(fields, debugEnabled: false), {'date': '2026-07-01', 'categoryId': 'c1'});
      expect(redactFields(fields, debugEnabled: true), fields);
    });

    test('nested maps are cleaned too', () {
      final out = redactFields({
        'query': {'budgetSyncId': 's', 'password': 'p', 'amountCents': 1},
      }, debugEnabled: false);
      expect(out, {
        'query': {'budgetSyncId': 's', 'password': redacted},
      });
    });
  });

  group('levels', () {
    test('debug is dropped without the flag; info, warn and error are always kept', () {
      _log.debug('detail');
      _log.info('happened');
      _log.warn('odd');
      _log.error('bug', StateError('x'), StackTrace.current);
      expect(Logs.memory.entries.map((e) => e.level), [LogLevel.info, LogLevel.warn, LogLevel.error]);
      expect(Logs.memory.entries.last.stack, isNotNull);
    });

    test('debug is kept with the flag, and turning it on is logged at info', () {
      Logs.setDebugEnabled(true);
      _log.debug('detail', {'payee': 'LIDL'});
      final entries = Logs.memory.entries;
      expect(entries.first.level, LogLevel.info);
      expect(entries.first.message, 'Debug logging on');
      expect(entries.last.fields, {'payee': 'LIDL'});
    });

    test('a payee logged at info is stripped when debug is off', () {
      _log.info('parsed', {'payee': 'LIDL', 'transactions': 3});
      expect(Logs.memory.entries.single.fields, {'transactions': 3});
    });

    test('clearDebug removes only debug lines', () async {
      Logs.setDebugEnabled(true);
      _log.debug('detail');
      _log.info('kept');
      await Logs.clearDebug();
      expect(Logs.memory.entries.every((e) => e.level != LogLevel.debug), isTrue);
      expect(Logs.memory.entries.map((e) => e.message), contains('kept'));
    });
  });

  group('HttpLogInterceptor', () {
    Dio dioWith(_FakeAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              o.headers['X-Import-Token'] = 'super-secret-token';
              h.next(o);
            },
          ),
        )
        ..interceptors.add(HttpLogInterceptor());
      return dio;
    }

    test('adds a request id, logs one info line, never the token or query values', () async {
      final adapter = _FakeAdapter(200, {'status': 'ok'});
      await dioWith(adapter).get('/accounts', queryParameters: {'budgetSyncId': 'b1', 'token': 'qs-secret'});

      final id = adapter.lastHeaders![requestIdHeader] as String;
      expect(id, hasLength(16));
      final entry = Logs.memory.entries.single;
      expect(entry.level, LogLevel.info);
      expect(entry.message, startsWith('GET /accounts 200 '));
      expect(entry.fields['req'], id);
      expect(_allText(), isNot(contains('super-secret-token')));
      expect(_allText(), isNot(contains('qs-secret')));
    });

    test('debug logs the query with secrets redacted', () async {
      Logs.setDebugEnabled(true);
      await dioWith(_FakeAdapter(200, {'status': 'ok'}))
          .get('/accounts', queryParameters: {'budgetSyncId': 'b1', 'token': 'qs-secret'});
      expect(_allText(), contains('budgetSyncId: b1'));
      expect(_allText(), isNot(contains('qs-secret')));
    });

    test("a failed request is a warn line with the backend's code", () async {
      await expectLater(
        dioWith(_FakeAdapter(422, {'error': 'nope', 'code': 'NO_TRANSACTIONS'})).post('/parse'),
        throwsA(isA<DioException>()),
      );
      final entry = Logs.memory.entries.single;
      expect(entry.level, LogLevel.warn);
      expect(entry.message, startsWith('POST /parse 422 '));
      expect(entry.fields['code'], 'NO_TRANSACTIONS');
    });
  });

  group('IoLogFileStore', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('logs_test'));
    tearDown(() async => dir.delete(recursive: true));

    LogEntry entry(LogLevel level, DateTime time, [String msg = 'm']) =>
        LogEntry(time: time, level: level, area: 'test', message: msg);

    test('writes one JSON line per entry into the day file', () async {
      final store = IoLogFileStore(dir);
      store.write(entry(LogLevel.info, DateTime.utc(2026, 11, 2, 10)));
      store.write(entry(LogLevel.error, DateTime.utc(2026, 11, 2, 11)));
      final files = await store.files();
      expect(files.map((f) => f.name), ['app-2026-11-02.log']);
      final lines = const LineSplitter().convert(utf8.decode(files.single.bytes));
      expect(lines.map((l) => (jsonDecode(l) as Map)['level']), ['info', 'error']);
    });

    test('prunes days older than the retention, never the newest file', () async {
      for (final day in ['2026-10-20', '2026-10-30', '2026-11-02']) {
        await File('${dir.path}/app-$day.log').writeAsString('{}\n');
      }
      final store = IoLogFileStore(dir, now: () => DateTime.utc(2026, 11, 2, 12));
      await store.pruneNow();
      expect((await store.files()).map((f) => f.name), ['app-2026-10-30.log', 'app-2026-11-02.log']);
    });

    test('prunes oldest files beyond the size cap', () async {
      for (final day in ['2026-10-31', '2026-11-01', '2026-11-02']) {
        await File('${dir.path}/app-$day.log').writeAsString('x' * 600);
      }
      final store = IoLogFileStore(dir, maxTotalBytes: 1000, now: () => DateTime.utc(2026, 11, 2));
      await store.pruneNow();
      expect((await store.files()).map((f) => f.name), ['app-2026-11-02.log']);
    });

    test('clearDebug rewrites the files without debug lines', () async {
      final store = IoLogFileStore(dir);
      store.write(entry(LogLevel.debug, DateTime.utc(2026, 11, 2), 'detail'));
      store.write(entry(LogLevel.info, DateTime.utc(2026, 11, 2), 'kept'));
      await store.clearDebug();
      final text = utf8.decode((await store.files()).single.bytes);
      expect(text, contains('kept'));
      expect(text, isNot(contains('detail')));
    });
  });

  group('log report', () {
    test('flags debug lines so the user is warned before sharing', () {
      final debugLine = LogEntry(time: DateTime.utc(2026), level: LogLevel.debug, area: 'a', message: 'm');
      final infoLine = LogEntry(time: DateTime.utc(2026), level: LogLevel.info, area: 'a', message: 'm');
      expect(buildLogReport(appFiles: null, memory: [infoLine], backendLog: null).containsDebug, isFalse);
      expect(buildLogReport(appFiles: null, memory: [debugLine], backendLog: null).containsDebug, isTrue);
      // pino's numeric debug level, as the backend's /logs returns it.
      expect(buildLogReport(appFiles: null, memory: [infoLine], backendLog: '{"level":20}').containsDebug, isTrue);
    });

    test('uses the files when there are any, and adds the backend log', () {
      final report = buildLogReport(
        appFiles: [LogFile('app-2026-11-02.log', Uint8List.fromList(utf8.encode('{}')))],
        memory: const [],
        backendLog: 'line',
      );
      expect(report.files.map((f) => f.name), ['app-2026-11-02.log', 'backend.log']);
    });
  });
}
