import 'dart:convert';

/// Severity, lowest first. Only [debug] depends on the debug flag; the
/// others are always written (see docs/plans/logging.md).
enum LogLevel {
  debug,
  info,
  warn,
  error;

  /// Fixed-width label for the human-readable line.
  String get label => name.toUpperCase().padRight(5);

  static LogLevel? tryParse(String? name) {
    for (final level in values) {
      if (level.name == name) return level;
    }
    return null;
  }
}

/// One log line. [fields] are already redacted when an entry is built by
/// `AppLog`, so sinks can write them as they are.
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String area;
  final String message;
  final Map<String, Object?> fields;
  final String? error;
  final String? stack;

  LogEntry({
    required DateTime time,
    required this.level,
    required this.area,
    required this.message,
    this.fields = const {},
    this.error,
    this.stack,
  }) : time = time.toUtc();

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'level': level.name,
    'area': area,
    'msg': message,
    if (fields.isNotEmpty) 'fields': fields,
    if (error != null) 'error': error,
    if (stack != null) 'stack': stack,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    time: DateTime.parse(json['time'] as String),
    level: LogLevel.tryParse(json['level'] as String?) ?? LogLevel.info,
    area: json['area'] as String? ?? '?',
    message: json['msg'] as String? ?? '',
    fields: (json['fields'] as Map?)?.cast<String, Object?>() ?? const {},
    error: json['error'] as String?,
    stack: json['stack'] as String?,
  );

  /// One JSON object per line: what the log files hold.
  String toJsonLine() => jsonEncode(toJson());

  /// `2026-11-02T10:15:03.120Z INFO  http     POST /parse 200 812ms req=7f3a`
  String toLine() {
    final buffer = StringBuffer()
      ..write(time.toIso8601String())
      ..write(' ')
      ..write(level.label)
      ..write(' ')
      ..write(area.padRight(8))
      ..write(' ')
      ..write(message);
    fields.forEach((key, value) => buffer.write(' $key=$value'));
    if (error != null) buffer.write('  $error');
    if (stack != null) buffer.write('\n$stack');
    return buffer.toString();
  }
}
