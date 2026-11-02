import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/log/app_log.dart';
import '../../core/log/log_entry.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import 'log_report.dart';

const _log = AppLog('ui');

/// Settings → Diagnostics: the verbose-logging switch, a live log viewer,
/// and Share / Copy / Clear for sending a log report.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

enum _Filter {
  all('All', LogLevel.debug),
  info('Info', LogLevel.info),
  warn('Warnings', LogLevel.warn),
  error('Errors', LogLevel.error);

  final String label;
  final LogLevel min;

  const _Filter(this.label, this.min);
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _debug = Logs.debugEnabled;
  _Filter _filter = _Filter.all;
  String _query = '';
  bool _busy = false;

  Future<void> _setDebug(bool value) async {
    setState(() => _debug = value);
    Logs.setDebugEnabled(value);
    await ref.read(settingsStoreProvider).setDebugLogging(value);
    if (value || !mounted) return;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete detailed lines?'),
        content: const Text(
          'Verbose logging is off. The detailed lines already recorded can include payee names. '
          'Delete them now? Info and error lines are kept.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (clear == true) await Logs.clearDebug();
  }

  Future<LogReport> _report() async {
    final hasBackend = ref.read(appConfigProvider).backendUrl != null;
    return buildLogReport(
      appFiles: await Logs.fileStore?.files(),
      memory: Logs.memory.entries,
      backendLog: hasBackend ? await ref.read(importerApiProvider).getBackendLogs() : null,
    );
  }

  /// Warns when the report holds debug lines (payee names). True = go on.
  Future<bool> _confirmDebug(LogReport report) async {
    if (!report.containsDebug) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('These logs include payee names'),
        content: const Text(
          'Verbose logging was on, so some lines name the payees of your transactions. '
          'Amounts and passwords are never logged. Share only with someone you trust.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e, st) {
      _log.error('Log report failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not prepare the logs.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _withBusy(() async {
    final report = await _report();
    if (!await _confirmDebug(report) || !mounted) return;
    _log.info('Sharing logs', {'files': report.files.length});
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Actual app logs',
        files: [for (final f in report.files) XFile.fromData(f.bytes, name: f.name, mimeType: 'text/plain')],
        fileNameOverrides: [for (final f in report.files) f.name],
      ),
    );
  });

  Future<void> _copy() => _withBusy(() async {
    final report = await _report();
    if (!await _confirmDebug(report)) return;
    await Clipboard.setData(ClipboardData(text: logReportAsText(report)));
    _log.info('Copied logs', {'files': report.files.length});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied.')));
    }
  });

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text("Deletes this phone's log files. The backend's logs aren't touched."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await Logs.clearAll();
      _log.info('Logs cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verbose logging'),
                  subtitle: Text(
                    'Also records detail for troubleshooting, including payee names. '
                    'Amounts and passwords are never logged.',
                    style: muted,
                  ),
                  value: _debug,
                  onChanged: _busy ? null : _setDebug,
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share logs'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _clear,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    for (final f in _Filter.values)
                      ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    hintText: 'Filter by area or text',
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: Space.sm),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<void>(
              stream: Logs.memory.changes,
              builder: (context, _) {
                final entries = Logs.memory.entries.reversed
                    .where((e) => e.level.index >= _filter.min.index)
                    .where(
                      (e) =>
                          _query.isEmpty ||
                          e.area.toLowerCase().contains(_query) ||
                          e.message.toLowerCase().contains(_query),
                    )
                    .toList();
                if (entries.isEmpty) {
                  return Center(child: Text('No log lines yet.', style: muted));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _EntryRow(entry: entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final LogEntry entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (entry.level) {
      LogLevel.debug => colors.onSurfaceVariant,
      LogLevel.info => colors.onSurface,
      LogLevel.warn => colors.tertiary,
      LogLevel.error => colors.error,
    };
    final small = figures(context.text.bodySmall);
    final time = entry.time.toLocal().toIso8601String().substring(11, 23);
    final details = [
      ...entry.fields.entries.map((f) => '${f.key}=${f.value}'),
      if (entry.error != null) entry.error!,
    ].join('  ');
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$time ${entry.level.label} ${entry.area}', style: small.copyWith(color: color)),
          Text(entry.message, style: context.text.bodyMedium),
          if (details.isNotEmpty) Text(details, style: small.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
    if (entry.stack == null) return row;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: row,
      children: [SelectableText(entry.stack!, style: small.copyWith(color: colors.onSurfaceVariant))],
    );
  }
}
