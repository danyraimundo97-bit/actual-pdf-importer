import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/models/import_result.dart';
import 'package:mobile_app/data/models/parse_result.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/import/inbox_controller.dart';

/// Parses by filename: ok.pdf succeeds, locked.pdf needs password "1234",
/// odd.pdf is an unknown bank.
class _FakeImporterApi implements ImporterApi {
  final parsed = <String>[];

  @override
  Future<ParseResult> parseStatement({
    required Uint8List bytes,
    required String filename,
    String? password,
    String? budgetSyncId,
  }) async {
    parsed.add(filename);
    switch (filename) {
      case 'locked.pdf' when password != '1234':
        throw ApiException(
          message: 'Password',
          code: password == null ? 'PDF_PASSWORD_REQUIRED' : 'PDF_PASSWORD_INCORRECT',
        );
      case 'odd.pdf':
        throw const ApiException(message: 'Unrecognized statement.', code: 'BANK_UNRECOGNIZED');
    }
    return const ParseResult(bankId: 'moey', transactions: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ProviderContainer container;
  late _FakeImporterApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = _FakeImporterApi();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        importerApiProvider.overrideWithValue(api),
      ],
    );
  });

  tearDown(() => container.dispose());

  InboxController inbox() => container.read(inboxProvider.notifier);
  List<InboxStatus> statuses() => container.read(inboxProvider).map((i) => i.status).toList();
  final pdf = Uint8List.fromList([1, 2, 3]);

  test('parses queued statements one at a time, in order', () async {
    inbox().add(filename: 'ok.pdf', bytes: pdf);
    inbox().add(filename: 'odd.pdf', bytes: pdf);
    await _settle();

    expect(api.parsed, ['ok.pdf', 'odd.pdf']);
    expect(statuses(), [InboxStatus.ready, InboxStatus.failed]);
    expect(container.read(inboxProvider)[1].error, contains('may not be supported'));
  });

  test('a locked statement waits for a password, then parses', () async {
    inbox().add(filename: 'locked.pdf', bytes: pdf);
    await _settle();
    expect(statuses(), [InboxStatus.needsPassword]);

    final id = container.read(inboxProvider).single.id;
    inbox().retry(id, password: 'wrong');
    await _settle();
    expect(statuses(), [InboxStatus.needsPassword]);
    expect(container.read(inboxProvider).single.wrongPassword, isTrue);

    inbox().retry(id, password: '1234');
    await _settle();
    expect(statuses(), [InboxStatus.ready]);
  });

  test('oversized files fail locally without an upload', () async {
    inbox().add(filename: 'huge.pdf', bytes: Uint8List(maxStatementBytes + 1));
    await _settle();

    expect(api.parsed, isEmpty);
    expect(statuses(), [InboxStatus.failed]);
  });

  test('imported and failed items are cleared, others are kept', () async {
    inbox().add(filename: 'ok.pdf', bytes: pdf);
    inbox().add(filename: 'odd.pdf', bytes: pdf);
    inbox().add(filename: 'locked.pdf', bytes: pdf);
    await _settle();
    final first = container.read(inboxProvider).first.id;
    inbox().markImported(first, const ImportResult(added: 3, updated: 0, categorized: 1));

    inbox().clearFinished();

    expect(container.read(inboxProvider).map((i) => i.filename), ['locked.pdf']);
  });
}
