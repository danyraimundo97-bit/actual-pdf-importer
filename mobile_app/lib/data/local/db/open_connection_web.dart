import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'database_opening.dart';

/// The web keeps drift's default database in the browser's storage,
/// unencrypted (docs/plans/local-ledger.md, Phase 1).
DatabaseConnection openAppDatabaseConnection({
  required Future<String> Function() key,
  void Function(DatabaseOpening outcome)? onOpened,
  Future<String> Function()? path,
}) => driftDatabase(name: 'app');
