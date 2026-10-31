import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/data/api/api_client.dart';
import 'package:mobile_app/data/local/secret_store.dart';

void main() {
  test('adds http:// when the scheme is missing', () {
    // Dio throws on a scheme-less base URL everywhere except web.
    expect(normalizeBackendUrl('localhost:3000'), 'http://localhost:3000');
    expect(normalizeBackendUrl(' 192.168.1.10:3000 '), 'http://192.168.1.10:3000');
  });

  test('keeps an explicit scheme and drops trailing slashes', () {
    expect(normalizeBackendUrl('https://importer.lan/'), 'https://importer.lan');
    expect(normalizeBackendUrl('http://10.0.2.2:3000//'), 'http://10.0.2.2:3000');
  });

  test('rejects what cannot be an importer address', () {
    expect(normalizeBackendUrl(''), isNull);
    expect(normalizeBackendUrl('   '), isNull);
    expect(normalizeBackendUrl('ftp://host:3000'), isNull);
    expect(normalizeBackendUrl('http://'), isNull);
  });

  test('a stored scheme-less address no longer crashes the client', () {
    expect(
      () => ApiClient(baseUrl: 'localhost:3000', secretStore: _NoSecrets()),
      returnsNormally,
    );
  });
}

class _NoSecrets implements SecretStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
