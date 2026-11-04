import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/api/backups_api.dart';
import 'package:mobile_app/data/local/db/app_data_file.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/models/backup_status.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/backups/screens/backups_screen.dart';

Map<String, dynamic> _decode(Uint8List bytes) => jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
Uint8List _encode(Object data) => Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(data))));

void main() {
  group('app-data file', () {
    late AppDatabase db;
    late LocalCategoryStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = LocalCategoryStore(db);
    });
    tearDown(() => db.close());

    test('export → import on an empty phone gives back categories, renames and memory', () async {
      await store.groups(); // seeds the presets
      await store.renameCategory(presetId('food.groceries'), 'Supermarket');
      final groups = await store.allGroups();
      final pets = await store.addCategory(groups.first.id, 'Pets');
      await store.remember('LIDL', presetId('food.groceries'));
      await store.remember('VET CLINIC', pets, budgetSyncId: 'b1');
      await store.remember('OLD SHOP', pets);
      await store.forget('OLD SHOP');

      final file = await exportAppDataFile(db, appVersion: '1.0.0');
      final data = _decode(file);
      expect(data['manifest'], containsPair('kind', 'app-data'));
      expect(data['manifest'], containsPair('schemaVersion', appDataSchemaVersion));
      expect((data['mappings'] as List).map((m) => m['payee']), unorderedEquals(['LIDL', 'VET CLINIC']));

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final otherStore = LocalCategoryStore(other);
      await otherStore.remember('SOMETHING ELSE', presetId('home.rent'));

      final result = await importAppDataFile(other, file);
      expect(result.mappings, 2);
      expect(result.forgotten, 1, reason: "the phone's own mapping isn't in the file");
      expect(result.skipped, 0);

      final names = {
        for (final g in await otherStore.groups())
          for (final c in g.categories) c.id: c.name,
      };
      expect(names[presetId('food.groceries')], 'Supermarket');
      expect(names[pets], 'Pets');
      expect((await otherStore.mappings()).map((m) => m.payee), ['LIDL']);
      expect((await otherStore.mappings(budgetSyncId: 'b1')).single.categoryId, pets);
    });

    test("a backend backup's Actual ids land through the phone's links", () async {
      await store.groups();
      await store.link(presetId('food.groceries'), 'b1', 'actual-groceries');
      final file = _encode({
        'manifest': {'kind': 'app-data', 'schemaVersion': 1},
        'appCategories': <Object>[],
        'mappings': [
          {'budgetSyncId': 'b1', 'payee': 'LIDL', 'categoryId': 'actual-groceries', 'updatedAt': 1},
          {'budgetSyncId': 'b1', 'payee': 'NOWHERE', 'categoryId': 'actual-unknown', 'updatedAt': 1},
        ],
        'removals': <Object>[],
      });
      final result = await importAppDataFile(db, file);
      expect(result.mappings, 1);
      expect(result.skipped, 1);
      expect((await store.mappings(budgetSyncId: 'b1')).single.categoryId, presetId('food.groceries'));
    });

    test('a newer or foreign file is refused', () async {
      expect(
        () => importAppDataFile(
          db,
          _encode({
            'manifest': {'kind': 'app-data', 'schemaVersion': 99},
            'appCategories': <Object>[],
            'mappings': <Object>[],
          }),
        ),
        throwsA(isA<AppDataFileException>().having((e) => e.code, 'code', 'BACKUP_TOO_NEW')),
      );
      expect(
        () => importAppDataFile(db, Uint8List.fromList(utf8.encode('hello'))),
        throwsA(isA<AppDataFileException>().having((e) => e.code, 'code', 'BACKUP_INVALID')),
      );
    });
  });

  group('backups screen', () {
    late AppDatabase db;
    late _FakeBackupsApi api;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = _FakeBackupsApi();
    });
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, {required bool backend}) async {
      SharedPreferences.setMockInitialValues({
        if (backend) 'backend_url': 'http://backend.test',
        'budget_sync_id': 'b1',
        'budget_name': 'Home',
        'onboarded': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            backupsApiProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(home: BackupsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('without a backend: only export and import', (tester) async {
      await pump(tester, backend: false);
      expect(find.text('Export app data'), findsOneWidget);
      expect(find.text('Import app data'), findsOneWidget);
      expect(find.text('Schedule'), findsNothing);
      expect(api.calls, isEmpty);
    });

    testWidgets('with a backend: schedule, lists, a failure explained, and changes saved', (tester) async {
      await pump(tester, backend: true);

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('App data'), findsWidgets);
      expect(find.text('Home'), findsOneWidget, reason: "the budget's section, by name");
      expect(find.text(_FakeBackupsApi.passwordMessage), findsOneWidget);
      expect(find.text('Give the backend the password'), findsOneWidget);
      expect(find.text('before a restore', findRichText: true), findsNothing);
      expect(find.textContaining('before a restore'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Weekly'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('settings frequency=weekly'));

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('runNow'));
      expect(find.text('Backed up.'), findsOneWidget);
    });
  });
}

class _FakeBackupsApi implements BackupsApi {
  static const passwordMessage = 'This budget is end-to-end encrypted.';
  final calls = <String>[];
  var frequency = 'daily';

  Map<String, dynamic> _json() => {
    'settings': {
      'frequency': frequency,
      'time': '03:00',
      'keep': 10,
      'budgets': [
        {'syncId': 'b1', 'name': 'Home', 'hasPassword': false},
      ],
    },
    'actualConfigured': true,
    'appData': {
      'folder': 'app-data',
      'backups': [
        {
          'folder': 'app-data',
          'file': '2026-11-03_030000.json.gz',
          'size': 2048,
          'createdAt': '2026-11-03T03:00:00.000Z',
          'beforeRestore': false,
        },
        {
          'folder': 'app-data',
          'file': '2026-11-02_120000-before-restore.json.gz',
          'size': 2000,
          'createdAt': '2026-11-02T12:00:00.000Z',
          'beforeRestore': true,
        },
      ],
      'last': {'lastAttemptAt': '2026-11-03T03:00:00.000Z', 'lastSuccessAt': '2026-11-03T03:00:00.000Z'},
      'nextDue': '2026-11-04T03:00:00.000Z',
    },
    'budgets': [
      {
        'folder': 'b1',
        'name': 'Home',
        'backups': <Object>[],
        'last': {
          'lastAttemptAt': '2026-11-03T03:00:00.000Z',
          'lastError': {'code': 'BUDGET_PASSWORD_REQUIRED', 'message': passwordMessage},
        },
        'nextDue': '2026-11-03T04:00:00.000Z',
      },
    ],
  };

  @override
  Future<BackupStatus> status() async {
    calls.add('status');
    return BackupStatus.fromJson(_json());
  }

  @override
  Future<BackupSettings> updateSettings({
    BackupFrequency? frequency,
    String? time,
    int? keep,
    List<Map<String, Object?>>? budgets,
  }) async {
    calls.add('settings frequency=${frequency?.name}');
    if (frequency != null) this.frequency = frequency.name;
    return BackupSettings.fromJson(_json()['settings'] as Map<String, dynamic>);
  }

  @override
  Future<({List<BackupRunResult> results, BackupStatus status})> runNow({String? kind, String? budgetSyncId}) async {
    calls.add('runNow');
    return (results: [const BackupRunResult(folder: 'app-data', ok: true)], status: BackupStatus.fromJson(_json()));
  }

  @override
  Future<Uint8List> download(BackupFile backup) async => Uint8List(0);

  @override
  Future<void> delete(BackupFile backup) async => calls.add('delete ${backup.file}');

  @override
  Future<({int mappings, int forgotten})> restoreAppData(BackupFile backup) async => (mappings: 0, forgotten: 0);
}
