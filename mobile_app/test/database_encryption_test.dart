import 'dart:io';
import 'dart:isolate';

import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/database_file.dart';
import 'package:mobile_app/data/local/db/database_opening.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/open_connection_native.dart';
import 'package:mobile_app/data/local/secret_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// docs/plans/local-ledger.md, Phase 1: the database file is encrypted with
// SQLite3MultipleCiphers (pubspec.yaml's sqlite3 hook option).

void main() {
  late Directory dir;
  late String path;
  final key = newDatabaseKey();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db-encryption-');
    path = '${dir.path}/app.sqlite';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase open({String? withKey}) =>
      AppDatabase(NativeDatabase(File(path), setup: withKey == null ? null : (db) => applyDatabaseKey(db, withKey)));

  Future<int> categoryCount(AppDatabase db) async => (await db.select(db.categories).get()).length;

  test('the SQLite build has encryption', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect(db.select('SELECT sqlite3mc_version() AS v').single['v'], isNotEmpty);
  });

  test('a new database is encrypted from the first write and opens again with its key', () async {
    expect(prepareDatabaseFileSync(path, key), DatabaseOpening.created);
    final db = open(withKey: key);
    final presets = await categoryCount(db);
    await db.close();

    expect(presets, greaterThan(0));
    expect(isPlainDatabase(File(path)), isFalse);
    expect(File(path).readAsBytesSync().take(16), isNot(equals('SQLite format 3\u0000'.codeUnits)));

    expect(prepareDatabaseFileSync(path, key), DatabaseOpening.opened);
    final again = open(withKey: key);
    expect(await categoryCount(again), presets);
    await again.close();
  });

  test('a plain database from before is encrypted in place, keeping its rows', () async {
    final plain = open();
    final group = (await plain.select(plain.categoryGroups).get()).first.id;
    final id = await LocalCategoryStore(plain).addCategory(group, 'Bike repairs');
    final before = await categoryCount(plain);
    await plain.close();
    expect(isPlainDatabase(File(path)), isTrue);

    expect(prepareDatabaseFileSync(path, key), DatabaseOpening.encrypted);
    expect(isPlainDatabase(File(path)), isFalse);
    expect(File('$path.pre-encryption').existsSync(), isFalse);

    final db = open(withKey: key);
    expect(await categoryCount(db), before);
    expect((await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle()).name, 'Bike repairs');
    await db.close();
  });

  test('a file the key does not open is set aside, and the app starts empty', () async {
    final db = open(withKey: key);
    await categoryCount(db);
    await db.close();

    expect(prepareDatabaseFileSync(path, newDatabaseKey()), DatabaseOpening.reset);
    expect(File(path).existsSync(), isFalse);
    expect(File('$path.unreadable').existsSync(), isTrue);
    // The original key still opens the file that was set aside.
    expect(prepareDatabaseFileSync('$path.unreadable', key), DatabaseOpening.opened);
  });

  test('a key that is not 64 hex characters is refused', () {
    expect(() => prepareDatabaseFileSync(path, "x'; DROP TABLE categories; --"), throwsArgumentError);
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect(() => applyDatabaseKey(db, 'abc'), throwsArgumentError);
  });

  test("drift_flutter's options can be sent to its database isolate", () async {
    final options = nativeDatabaseOptions(path, key);
    // drift_flutter sends the options to the isolate that opens the file;
    // a closure holding anything that can't be sent would fail there.
    expect(await Isolate.run(() => options.databasePath!()), path);
  });

  group('SecretStore.databaseKey', () {
    test('is created once and kept by "wipe everything"', () async {
      FlutterSecureStorage.setMockInitialValues({'api_token': 'secret'});
      final store = SecretStore(const FlutterSecureStorage());
      final first = await store.databaseKey();
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await store.databaseKey(), first);

      await store.clearAll();
      expect(await store.apiToken, isNull);
      expect(await store.databaseKey(), first);
    });
  });
}
