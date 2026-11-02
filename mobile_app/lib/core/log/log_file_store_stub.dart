import 'log_file_store.dart';

/// Web: no file system, so there's no file store; the in-memory buffer is
/// the only record there.
Future<LogFileStore?> openLogFileStore() async => null;
