import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'log_entry.dart';

/// Where log entries go. Implementations must never throw from [write]:
/// a broken log sink must not take the app down with it.
abstract class LogSink {
  void write(LogEntry entry);

  /// Pushes anything buffered to its destination.
  Future<void> flush() async {}

  /// Removes everything this sink has stored.
  Future<void> clear() async {}
}

/// The console, via `dart:developer` so lines show up in DevTools and
/// `flutter run` with their level. Only installed in debug builds.
class ConsoleSink extends LogSink {
  @override
  void write(LogEntry entry) {
    developer.log(
      entry.toLine(),
      name: entry.area,
      level: switch (entry.level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
      time: entry.time,
    );
  }
}

/// The last [capacity] entries, in memory. Backs the log viewer on every
/// platform, and is the only store on web, where there's no file system.
class MemorySink extends LogSink {
  final int capacity;
  final _entries = ListQueue<LogEntry>();
  final _changes = StreamController<void>.broadcast();

  MemorySink({this.capacity = 2000});

  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Fires after every write or clear, for a live viewer.
  Stream<void> get changes => _changes.stream;

  @override
  void write(LogEntry entry) {
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _changes.add(null);
  }

  /// Drops debug entries only (turning the debug flag off offers this).
  void clearDebug() {
    _entries.removeWhere((e) => e.level == LogLevel.debug);
    _changes.add(null);
  }
}
