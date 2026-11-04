import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'database_file.dart';
import 'database_opening.dart';

/// Opens the app's database file, encrypted with [key] (SecretStore's
/// database key). [onOpened] hears what happened to the file first
/// ([DatabaseOpening]); [path] replaces the default, drift_flutter's
/// `<documents>/app.sqlite`, so existing installs keep their file.
DatabaseConnection openAppDatabaseConnection({
  required Future<String> Function() key,
  void Function(DatabaseOpening outcome)? onOpened,
  Future<String> Function()? path,
}) {
  return DatabaseConnection.delayed(
    Future(() async {
      final file = await (path ?? _defaultPath)();
      final hexKey = await key();
      final outcome = await prepareDatabaseFile(file, hexKey);
      onOpened?.call(outcome);
      return driftDatabase(name: 'app', native: nativeDatabaseOptions(file, hexKey));
    }),
  );
}

Future<String> _defaultPath() async => '${(await getApplicationDocumentsDirectory()).path}/app.sqlite';

// A top-level function, so the closures carry only the two strings: drift
// sends them to the isolate that opens the database.
@visibleForTesting
DriftNativeOptions nativeDatabaseOptions(String file, String hexKey) =>
    DriftNativeOptions(databasePath: () async => file, setup: (db) => applyDatabaseKey(db, hexKey));
