import 'dart:convert';
import 'dart:typed_data';

import '../../core/log/log_entry.dart';
import '../../core/log/log_file_store.dart';

/// What "Share logs" sends: the app's log files (or, on web, the in-memory
/// lines as one file) plus the backend's recent lines when it could be
/// reached.
class LogReport {
  final List<LogFile> files;

  /// Whether any file holds debug lines, which can contain payee names:
  /// the user is warned before sharing.
  final bool containsDebug;

  const LogReport(this.files, {required this.containsDebug});

  bool get isEmpty => files.every((f) => f.bytes.isEmpty);
}

final _debugMarker = '"level":"${LogLevel.debug.name}"';

LogReport buildLogReport({
  required List<LogFile>? appFiles,
  required List<LogEntry> memory,
  required String? backendLog,
}) {
  final files = <LogFile>[
    if (appFiles != null)
      ...appFiles
    else
      LogFile('app-memory.log', Uint8List.fromList(utf8.encode(memory.map((e) => '${e.toJsonLine()}\n').join()))),
    if (backendLog != null && backendLog.isNotEmpty)
      LogFile('backend.log', Uint8List.fromList(utf8.encode(backendLog))),
  ];
  final containsDebug = files.any((f) {
    final text = utf8.decode(f.bytes, allowMalformed: true);
    return text.contains(_debugMarker) || text.contains('"level":20') || text.contains(' DEBUG ');
  });
  return LogReport(files, containsDebug: containsDebug);
}

/// Plain-text version of [report] for "Copy logs".
String logReportAsText(LogReport report) =>
    report.files.map((f) => '===== ${f.name} =====\n${utf8.decode(f.bytes, allowMalformed: true)}').join('\n');
