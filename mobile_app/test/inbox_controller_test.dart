import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/data/api/categories_api.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/models/actual_category.dart';
import 'package:mobile_app/data/models/category_mapping.dart';
import 'package:mobile_app/data/models/import_result.dart';
import 'package:mobile_app/data/models/parse_result.dart';
import 'package:mobile_app/data/pdf/pdf_text_extractor.dart';
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
      case 'no-ai.pdf':
        throw const ApiException(message: 'No AI provider.', code: 'AI_NOT_CONFIGURED');
    }
    return const ParseResult(bankId: 'moey', transactions: []);
  }

  @override
  Future<List<ActualCategoryGroup>> getActualCategories({String? budgetSyncId}) async => const [
    ActualCategoryGroup(id: 'g', name: 'Everyday', categories: [ActualCategory(id: 'a-cafes', name: 'Cafés')]),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The PDF's first byte picks what the "PDF" is: see [_DeviceFile].
class _FakeExtractor implements PdfTextExtractor {
  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    switch (_DeviceFile.values[bytes.first]) {
      case _DeviceFile.moey:
        return File('../fixtures/parsers/moey-basic.pdfium.txt').readAsStringSync();
      case _DeviceFile.unknownBank:
        return 'Some other bank\n01-01-2026 COFFEE 2,50';
      case _DeviceFile.locked when password != '1234':
        throw PdfReadException(password == null ? PdfReadFailure.passwordRequired : PdfReadFailure.passwordIncorrect);
      case _DeviceFile.locked:
        return File('../fixtures/parsers/moey-basic.pdfium.txt').readAsStringSync();
      case _DeviceFile.notPdf:
        throw const PdfReadException(PdfReadFailure.unreadable);
    }
  }
}

enum _DeviceFile { moey, unknownBank, locked, notPdf }

Uint8List _file(_DeviceFile f) => Uint8List.fromList([f.index]);

/// Category memory with one mapping per scope.
class _FakeCategoriesApi implements CategoriesApi {
  _FakeCategoriesApi({this.fail = false});
  final bool fail;
  final scopes = <String?>[];

  @override
  Future<List<CategoryMapping>> list({String? budgetSyncId}) async {
    scopes.add(budgetSyncId);
    if (fail) throw const ApiException(message: 'Could not reach the importer backend.');
    return [
      if (budgetSyncId == null) const CategoryMapping(payee: 'any', categoryId: 'old', updatedAt: ''),
      if (budgetSyncId != null) CategoryMapping(payee: _firstPayee, categoryId: 'cat-1', updatedAt: ''),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The first movement's payee in moey-basic, in different case and
/// spacing, to prove the match is normalised like the backend's.
final _firstPayee = () {
  final expected = jsonDecode(File('../fixtures/parsers/moey-basic.expected.json').readAsStringSync());
  final payee = (expected['transactions'] as List).first['payee'] as String;
  return '  ${payee.toUpperCase().replaceAll(' ', '   ')} ';
}();

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ProviderContainer container;
  late _FakeImporterApi api;

  setUp(() async {
    // These cover the backend parser: Settings → "Read statements on
    // this phone" off. The on-device path is the group further down.
    SharedPreferences.setMockInitialValues({'parse_on_device': false});
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

  test("a backend without an AI provider says how to read the statement instead", () async {
    inbox().add(filename: 'no-ai.pdf', bytes: pdf);
    await _settle();

    expect(statuses(), [InboxStatus.failed]);
    expect(container.read(inboxProvider).single.error, contains('Read statements on this phone'));
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

  group('on the device', () {
    late ProviderContainer device;
    late _FakeCategoriesApi categories;

    /// [actual]: the backend reports Actual connected with a budget.
    Future<void> start({String? backendUrl, bool categoriesFail = false, bool actual = false}) async {
      SharedPreferences.setMockInitialValues({
        'backend_url': ?backendUrl,
        if (backendUrl != null) 'budget_sync_id': 'budget-1',
      });
      final prefs = await SharedPreferences.getInstance();
      categories = _FakeCategoriesApi(fail: categoriesFail);
      device = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          importerApiProvider.overrideWithValue(api),
          categoriesApiProvider.overrideWithValue(categories),
          pdfTextExtractorProvider.overrideWithValue(_FakeExtractor()),
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          if (actual) linkStateProvider.overrideWith((ref) async => LinkState.ready),
        ],
      );
      addTearDown(device.dispose);
    }

    InboxController deviceInbox() => device.read(inboxProvider.notifier);

    // Parsing runs in a background isolate (compute), so wait for real
    // until nothing is queued or being read.
    Future<void> idle() async {
      bool busy() =>
          device.read(inboxProvider).any((i) => i.status == InboxStatus.queued || i.status == InboxStatus.parsing);
      for (var i = 0; i < 500 && (busy() || i == 0); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await _settle();
    }

    InboxItem only() => device.read(inboxProvider).single;

    test('reads a known bank without uploading it, and without a backend', () async {
      await start();
      deviceInbox().add(filename: 'moey.pdf', bytes: _file(_DeviceFile.moey));
      await idle();

      expect(api.parsed, isEmpty);
      expect(categories.scopes, isEmpty, reason: 'no backend, so nothing to ask');
      expect(only().status, InboxStatus.ready);
      expect(only().parsedOnDevice, isTrue);
      expect(only().parseResult!.bankId, 'moey');
      expect(only().parseResult!.transactions, isNotEmpty);
      expect(only().parseResult!.localCategories, isTrue);
    });

    test("with Actual connected, suggests from the backend's memory, budget first", () async {
      await start(backendUrl: 'http://backend', actual: true);
      deviceInbox().add(filename: 'moey.pdf', bytes: _file(_DeviceFile.moey));
      await idle();

      expect(api.parsed, isEmpty, reason: 'only the mappings are fetched, never the PDF');
      expect(categories.scopes, ['budget-1', null]);
      final txs = only().parseResult!.transactions;
      expect(txs.first.suggestedCategoryId, 'cat-1');
      expect(txs.skip(1).every((t) => t.suggestedCategoryId == null), isTrue);
      expect(only().parseResult!.localCategories, isFalse);
    });

    test("without Actual, suggests from the phone's memory and never asks the backend", () async {
      await start(backendUrl: 'http://backend');
      final payee = _firstPayee.trim();
      await device.read(localCategoryStoreProvider).remember(payee, 'preset:food.groceries');
      deviceInbox().add(filename: 'moey.pdf', bytes: _file(_DeviceFile.moey));
      await idle();

      expect(categories.scopes, isEmpty);
      final first = only().parseResult!.transactions.first;
      expect(first.suggestedCategoryId, 'preset:food.groceries');
      expect(first.suggestedCategoryName, 'Groceries');
      expect(first.suggestedFromHint, isFalse);
      expect(only().parseResult!.localCategories, isTrue);
    });

    test("with Actual connected, the phone's memory fills gaps through linked categories", () async {
      await start(backendUrl: 'http://backend', actual: true);
      final store = device.read(localCategoryStoreProvider);
      // The second movement's payee, remembered offline; its category is
      // linked to an Actual one. The first gets the backend's mapping.
      final expected = jsonDecode(File('../fixtures/parsers/moey-basic.expected.json').readAsStringSync());
      final second = (expected['transactions'] as List)[1]['payee'] as String;
      await store.remember(second, 'preset:food.restaurants', budgetSyncId: 'budget-1');
      await store.link('preset:food.restaurants', 'budget-1', 'a-cafes');

      deviceInbox().add(filename: 'moey.pdf', bytes: _file(_DeviceFile.moey));
      await idle();

      final txs = only().parseResult!.transactions;
      expect(txs[0].suggestedCategoryId, 'cat-1', reason: "the backend's memory comes first");
      expect(txs[1].suggestedCategoryId, 'a-cafes');
      expect(txs[1].suggestedCategoryName, 'Cafés');
      expect(txs.every((t) => !LocalCategoryStore.isLocalId(t.suggestedCategoryId ?? '')), isTrue);
      expect(only().parseResult!.localCategories, isFalse);
    });

    test('an unreachable backend still gives a reviewable statement', () async {
      await start(backendUrl: 'http://backend', categoriesFail: true, actual: true);
      deviceInbox().add(filename: 'moey.pdf', bytes: _file(_DeviceFile.moey));
      await idle();

      expect(only().status, InboxStatus.ready);
      expect(only().parseResult!.localCategories, isTrue, reason: "fell back to the phone's memory");
    });

    test('an unknown bank waits for the user before anything is uploaded', () async {
      await start(backendUrl: 'http://backend');
      deviceInbox().add(filename: 'odd.pdf', bytes: _file(_DeviceFile.unknownBank));
      await idle();

      expect(only().status, InboxStatus.unrecognized);
      expect(only().recognizedBank, isNull);
      expect(api.parsed, isEmpty);

      deviceInbox().sendToBackend(only().id);
      await idle();

      expect(api.parsed, ['odd.pdf']);
      expect(only().status, InboxStatus.failed, reason: 'the fake backend does not know it either');
    });

    test('a locked statement asks for the password, then keeps it for the backend', () async {
      await start();
      deviceInbox().add(filename: 'locked.pdf', bytes: _file(_DeviceFile.locked));
      await idle();
      expect(only().status, InboxStatus.needsPassword);
      expect(only().wrongPassword, isFalse);

      deviceInbox().retry(only().id, password: 'nope');
      await idle();
      expect(only().status, InboxStatus.needsPassword);
      expect(only().wrongPassword, isTrue);

      deviceInbox().retry(only().id, password: '1234');
      await idle();
      expect(only().status, InboxStatus.ready);
      expect(only().password, '1234');
    });

    test('a file that is not a PDF fails', () async {
      await start();
      deviceInbox().add(filename: 'notes.pdf', bytes: _file(_DeviceFile.notPdf));
      await idle();

      expect(only().status, InboxStatus.failed);
      expect(api.parsed, isEmpty);
    });

    test('turning the setting off sends statements to the backend again', () async {
      await start(backendUrl: 'http://backend');
      device.read(parseOnDeviceProvider.notifier).state = false;
      deviceInbox().add(filename: 'ok.pdf', bytes: _file(_DeviceFile.moey));
      await idle();

      expect(api.parsed, ['ok.pdf']);
      expect(only().parsedOnDevice, isFalse);
    });
  });
}
