import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/log/app_log.dart';
import 'database_opening.dart';

// The app's database file is encrypted (docs/plans/local-ledger.md,
// Phase 1) with SQLite3MultipleCiphers, selected in pubspec.yaml's
// `hooks: user_defines: sqlite3: source: sqlite3mc`. The key is 32 random
// bytes kept in the phone's secure storage (SecretStore.databaseKey); it
// never reaches a log, a backup or the backend.

const _log = AppLog('database');

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

/// Applies [hexKey] to a connection that was just opened. Throws on a
/// SQLite without encryption, so the app never quietly writes a plain file.
void applyDatabaseKey(CommonDatabase db, String hexKey) {
  if (!_hexKey.hasMatch(hexKey)) throw ArgumentError('The database key must be 64 hex characters.');
  _requireCiphers();
  db.execute("PRAGMA hexkey = '$hexKey'");
}

bool? _hasCiphers;

/// Checked once, on an in-memory database: on an encrypted file any query
/// before the key fails, whichever SQLite it is.
void _requireCiphers() {
  _hasCiphers ??= () {
    final db = sqlite3.openInMemory();
    try {
      db.select('SELECT sqlite3mc_version()');
      return true;
    } on SqliteException {
      return false;
    } finally {
      db.close();
    }
  }();
  if (!_hasCiphers!) {
    throw StateError(
      'This SQLite has no encryption. Check `hooks: user_defines: sqlite3: source: sqlite3mc` in pubspec.yaml.',
    );
  }
}

const _plainHeader = 'SQLite format 3\u0000';

/// Whether [file] is an unencrypted SQLite database (its first 16 bytes are
/// SQLite's magic header; an encrypted file's are random).
bool isPlainDatabase(File file) {
  if (!file.existsSync() || file.lengthSync() < 16) return false;
  final raf = file.openSync();
  try {
    return String.fromCharCodes(raf.readSync(16)) == _plainHeader;
  } finally {
    raf.closeSync();
  }
}

/// Gets the file at [path] ready to be opened with [hexKey]. Runs on a
/// background isolate (blocking file and SQLite work).
Future<DatabaseOpening> prepareDatabaseFile(String path, String hexKey) async {
  final outcome = await Isolate.run(() => prepareDatabaseFileSync(path, hexKey));
  switch (outcome) {
    case DatabaseOpening.reset:
      _log.warn('The database key does not open the database: it was set aside and the app starts empty');
    case DatabaseOpening.encrypted:
      _log.info('Database encrypted');
    case DatabaseOpening.created || DatabaseOpening.opened:
      _log.debug('Database ready', {'outcome': outcome.name});
  }
  return outcome;
}

DatabaseOpening prepareDatabaseFileSync(String path, String hexKey) {
  if (!_hexKey.hasMatch(hexKey)) throw ArgumentError('The database key must be 64 hex characters.');
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() == 0) return DatabaseOpening.created;
  if (isPlainDatabase(file)) {
    _encryptInPlace(file, hexKey);
    return DatabaseOpening.encrypted;
  }
  if (_opensWith(path, hexKey)) return DatabaseOpening.opened;
  _setAside(file);
  return DatabaseOpening.reset;
}

bool _opensWith(String path, String hexKey) {
  final db = sqlite3.open(path);
  try {
    applyDatabaseKey(db, hexKey);
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on SqliteException {
    return false;
  } finally {
    db.close();
  }
}

/// SQLite3MultipleCiphers encrypts a plain database with `PRAGMA rekey`.
/// A copy is kept until the encrypted file has been read back, and put back
/// if anything fails, so a crash halfway never loses the categories.
void _encryptInPlace(File file, String hexKey) {
  final copy = File('${file.path}.pre-encryption');
  file.copySync(copy.path);
  try {
    final db = sqlite3.open(file.path);
    try {
      _requireCiphers();
      // rekey can't run on a WAL database; drift uses the default
      // rollback journal, but make sure.
      db.execute('PRAGMA journal_mode = DELETE');
      db.execute("PRAGMA hexrekey = '$hexKey'");
    } finally {
      db.close();
    }
    if (isPlainDatabase(file) || !_opensWith(file.path, hexKey)) {
      throw StateError('The database was not encrypted.');
    }
    copy.deleteSync();
  } catch (_) {
    copy.copySync(file.path);
    copy.deleteSync();
    rethrow;
  }
}

/// Keeps one unreadable file (the newest), in case the key turns up again.
void _setAside(File file) {
  file.renameSync('${file.path}.unreadable');
  for (final suffix in const ['-journal', '-wal', '-shm']) {
    final extra = File('${file.path}$suffix');
    if (extra.existsSync()) extra.deleteSync();
  }
}
