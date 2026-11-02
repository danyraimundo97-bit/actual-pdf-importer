import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_entry.dart';
import 'log_file_store.dart';

/// Opens the store in `<app support dir>/logs`. Returns null rather than
/// throwing if that directory can't be used: logging must never stop the
/// app from starting.
Future<LogFileStore?> openLogFileStore() async {
  try {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/logs');
    await dir.create(recursive: true);
    return IoLogFileStore(dir);
  } catch (_) {
    return null;
  }
}

/// Daily files `app-YYYY-MM-DD.log`, one JSON object per line.
///
/// Writes are buffered and flushed every [flushInterval], and immediately
/// for an error so a crash right after it can't lose the line. Old files
/// are pruned to [retention] days and [maxTotalBytes] in total, whichever
/// is smaller; the newest file is never deleted.
class IoLogFileStore extends LogFileStore {
  final Directory dir;
  final Duration retention;
  final int maxTotalBytes;
  final Duration flushInterval;
  final DateTime Function() _now;

  final _pending = <LogEntry>[];
  Timer? _timer;
  Future<void> _queue = Future.value();
  String? _prunedForDay;

  IoLogFileStore(
    this.dir, {
    this.retention = const Duration(days: 7),
    this.maxTotalBytes = 5 * 1024 * 1024,
    this.flushInterval = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static final _namePattern = RegExp(r'^app-(\d{4}-\d{2}-\d{2})\.log$');

  static String _day(DateTime t) => t.toUtc().toIso8601String().substring(0, 10);

  @override
  void write(LogEntry entry) {
    _pending.add(entry);
    if (entry.level == LogLevel.error) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushInterval, () => unawaited(flush()));
    }
  }

  /// Runs [task] after everything queued before it, so appends, prunes and
  /// rewrites never interleave.
  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task()).catchError((Object _) {});
    _queue = next;
    return next;
  }

  @override
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return _queue;
    final batch = List.of(_pending);
    _pending.clear();
    return _serial(() async {
      final byDay = <String, StringBuffer>{};
      for (final entry in batch) {
        (byDay[_day(entry.time)] ??= StringBuffer()).writeln(entry.toJsonLine());
      }
      for (final MapEntry(key: day, value: text) in byDay.entries) {
        await File('${dir.path}/app-$day.log').writeAsString(text.toString(), mode: FileMode.append, flush: true);
      }
      final today = _day(_now());
      if (_prunedForDay != today) {
        _prunedForDay = today;
        await _prune();
      }
    });
  }

  Future<List<File>> _logFiles() async {
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File && _namePattern.hasMatch(e.uri.pathSegments.last)) files.add(e);
    }
    files.sort((a, b) => a.path.compareTo(b.path)); // names sort by date
    return files;
  }

  Future<void> _prune() async {
    final files = await _logFiles();
    if (files.isEmpty) return;
    final cutoff = _day(_now().subtract(retention));
    final keep = <File>[];
    for (final f in files) {
      final day = _namePattern.firstMatch(f.uri.pathSegments.last)!.group(1)!;
      if (day.compareTo(cutoff) <= 0 && f != files.last) {
        await f.delete();
      } else {
        keep.add(f);
      }
    }
    var total = 0;
    for (final f in keep) {
      total += await f.length();
    }
    while (total > maxTotalBytes && keep.length > 1) {
      final oldest = keep.removeAt(0);
      total -= await oldest.length();
      await oldest.delete();
    }
  }

  /// Exposed for tests: prune now, regardless of the once-a-day rule.
  Future<void> pruneNow() => _serial(_prune);

  @override
  Future<List<LogFile>> files() async {
    await flush();
    final out = <LogFile>[];
    for (final f in await _logFiles()) {
      out.add(LogFile(f.uri.pathSegments.last, await f.readAsBytes()));
    }
    return out;
  }

  @override
  Future<void> clear() async {
    _pending.clear();
    await _serial(() async {
      for (final f in await _logFiles()) {
        await f.delete();
      }
    });
  }

  @override
  Future<void> clearDebug() async {
    _pending.removeWhere((e) => e.level == LogLevel.debug);
    await flush();
    await _serial(() async {
      for (final f in await _logFiles()) {
        final kept = (await f.readAsLines()).where((line) {
          try {
            return (jsonDecode(line) as Map)['level'] != LogLevel.debug.name;
          } catch (_) {
            return true; // keep lines we can't read rather than lose them
          }
        });
        await f.writeAsString(kept.map((l) => '$l\n').join(), flush: true);
      }
    });
  }
}
