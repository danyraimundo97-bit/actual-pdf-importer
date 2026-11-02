import 'log_entry.dart';
import 'log_file_store.dart';
import 'redaction.dart';
import 'sinks.dart';

export 'log_entry.dart' show LogLevel;

/// The app's logging hub: one set of sinks and one debug flag for every
/// `AppLog`. Configured once in `main()` via [Logs.init].
///
/// Levels (docs/plans/logging.md): debug is written only while
/// [debugEnabled]; info, warn and error are always written.
class Logs {
  Logs._();

  /// Compile-time default for the debug flag:
  /// `flutter run --dart-define=LOG_DEBUG=true` (dev.json sets it too).
  static const debugDefault = bool.fromEnvironment('LOG_DEBUG');

  static final MemorySink memory = MemorySink();
  static LogFileStore? _fileStore;
  static final List<LogSink> _sinks = [memory];
  static bool _debug = debugDefault;
  static DateTime Function() _now = DateTime.now;

  static bool get debugEnabled => _debug;

  /// The on-device files, or null on web or when they couldn't be opened.
  static LogFileStore? get fileStore => _fileStore;

  /// Installs the extra sinks and the effective debug flag (the user's
  /// runtime choice from Settings, or [debugDefault]).
  static void init({List<LogSink> sinks = const [], LogFileStore? fileStore, bool? debugEnabled}) {
    _sinks
      ..clear()
      ..add(memory)
      ..addAll(sinks);
    _fileStore = fileStore;
    if (fileStore != null) _sinks.add(fileStore);
    _debug = debugEnabled ?? debugDefault;
  }

  /// Turning the flag on or off is itself logged, at info.
  static void setDebugEnabled(bool value) {
    if (value == _debug) return;
    _debug = value;
    const AppLog('app').info('Debug logging ${value ? 'on' : 'off'}');
  }

  static void emit(
    LogLevel level,
    String area,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stack,
  }) {
    if (level == LogLevel.debug && !_debug) return;
    final entry = LogEntry(
      time: _now(),
      level: level,
      area: area,
      message: message,
      fields: fields.isEmpty ? const {} : redactFields(fields, debugEnabled: _debug),
      error: error?.toString(),
      stack: stack?.toString(),
    );
    for (final sink in _sinks) {
      try {
        sink.write(entry);
      } catch (_) {
        // A failing sink must never break the caller.
      }
    }
  }

  static Future<void> flush() async {
    for (final sink in _sinks) {
      await sink.flush();
    }
  }

  static Future<void> clearAll() async {
    for (final sink in _sinks) {
      await sink.clear();
    }
  }

  /// Removes debug lines from memory and the files (offered when the user
  /// turns the flag off, since debug lines can hold payee names).
  static Future<void> clearDebug() async {
    memory.clearDebug();
    await _fileStore?.clearDebug();
  }

  /// Tests only: back to a clean state with a fixed clock.
  static void resetForTest({bool debugEnabled = false, List<LogSink> sinks = const [], DateTime Function()? now}) {
    memory.clear();
    init(sinks: sinks, debugEnabled: debugEnabled);
    _now = now ?? DateTime.now;
  }
}

/// A logger for one area of the app (`http`, `import`, `ui`, `nav`, …):
///
/// ```dart
/// const _log = AppLog('import');
/// _log.info('Statement parsed', {'bank': 'moey', 'transactions': 37});
/// ```
///
/// Field names decide what gets written (see redaction.dart): amounts
/// never, payees only at debug, secrets replaced.
class AppLog {
  final String area;

  const AppLog(this.area);

  void debug(String message, [Map<String, Object?> fields = const {}]) =>
      Logs.emit(LogLevel.debug, area, message, fields: fields);

  void info(String message, [Map<String, Object?> fields = const {}]) =>
      Logs.emit(LogLevel.info, area, message, fields: fields);

  void warn(String message, [Map<String, Object?> fields = const {}]) =>
      Logs.emit(LogLevel.warn, area, message, fields: fields);

  /// For bugs: unexpected failures, always with the [error] and its [stack].
  void error(String message, Object? error, StackTrace? stack, [Map<String, Object?> fields = const {}]) =>
      Logs.emit(LogLevel.error, area, message, fields: fields, error: error, stack: stack);
}
