import 'dart:typed_data';

import 'sinks.dart';

export 'log_file_store_stub.dart' if (dart.library.io) 'log_file_store_io.dart' show openLogFileStore;

/// One stored log file, read back for sharing.
class LogFile {
  final String name;
  final Uint8List bytes;

  const LogFile(this.name, this.bytes);
}

/// The on-device log files: always written for info/warn/error (and debug
/// when the flag is on), so a build installed on a phone with no terminal
/// attached still has a record. Not available on web (see the stub).
abstract class LogFileStore extends LogSink {
  /// Every stored file, oldest first.
  Future<List<LogFile>> files();

  /// Rewrites the files without their debug lines.
  Future<void> clearDebug();
}
