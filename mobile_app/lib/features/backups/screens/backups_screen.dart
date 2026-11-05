import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/db/app_data_file.dart';
import '../../../data/models/backup_status.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../categories/category_sync_controller.dart';

const _log = AppLog('backups');

/// Written into exported app-data files' manifest. Keep in step with pubspec.yaml.
const _appVersion = '1.0.0';

/// Settings → Backups (docs/plans/backups.md, Phase 4). With a backend: the
/// schedule, the last and next backup, and each backup to share, delete or
/// (app data) restore. Always: exporting and importing this phone's app
/// data by hand, which is all there is without a backend.
class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});

  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  BackupStatus? _status;
  String? _error;
  bool _running = false;
  bool _working = false;

  bool get _hasBackend => ref.read(appConfigProvider).backendUrl?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    if (_hasBackend) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final status = await ref.read(backupsApiProvider).status();
      if (mounted) setState(() => _status = status);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveSettings({
    BackupFrequency? frequency,
    String? time,
    int? keep,
    List<Map<String, Object?>>? budgets,
  }) async {
    try {
      await ref.read(backupsApiProvider).updateSettings(frequency: frequency, time: time, keep: keep, budgets: budgets);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _pickTime(String current) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      helpText: "Time on the backend's clock",
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    await _saveSettings(time: '${two(picked.hour)}:${two(picked.minute)}');
  }

  /// Adds or removes the chosen budget from the scheduled ones.
  Future<void> _toggleBudget(BackupSettings settings, String syncId, String? name, bool on) async {
    final others = [
      for (final b in settings.budgets)
        if (b.syncId != syncId) b.toJson(),
    ];
    await _saveSettings(
      budgets: on ? [...others, BackupBudgetChoice(syncId: syncId, name: name).toJson()] : others,
    );
  }

  Future<void> _givePassword(BackupSettings settings, BackupTarget target) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Budget password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This budget is end-to-end encrypted. The backend keeps its password, only to make '
              'backups, in a file only it can read.',
            ),
            const SizedBox(height: Space.lg),
            TextField(controller: controller, obscureText: true, autofocus: true, autocorrect: false),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    await _saveSettings(
      budgets: [
        for (final b in settings.budgets) b.syncId == target.folder ? b.toJson(password: password) : b.toJson(),
      ],
    );
  }

  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      final run = await ref.read(backupsApiProvider).runNow();
      if (!mounted) return;
      setState(() => _status = run.status);
      final failed = run.results.where((r) => !r.ok).toList();
      _snack(
        failed.isEmpty
            ? 'Backed up.'
            : failed.length == run.results.length
            ? (failed.first.errorMessage ?? 'The backup failed.')
            : '${run.results.length - failed.length} of ${run.results.length} backed up. '
                  '${failed.first.errorMessage ?? ''}',
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _share(BackupFile backup) async {
    setState(() => _working = true);
    try {
      final bytes = await ref.read(backupsApiProvider).download(backup);
      _log.info('Sharing a backup', {'folder': backup.folder, 'file': backup.file});
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: backup.file, mimeType: _mimeType(backup.file))],
          fileNameOverrides: [backup.file],
        ),
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(BackupFile backup) async {
    final ok = await _confirm(
      title: 'Delete this backup?',
      message: 'The backup from ${_when(backup.createdAt)} is deleted from the backend. This can’t be undone.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(backupsApiProvider).delete(backup);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _restore(BackupFile backup) async {
    final ok = await _confirm(
      title: 'Restore app data?',
      message:
          'The categories and category memory go back to how they were on ${_when(backup.createdAt)}, '
          'on the backend, on this phone, and on other phones when they next sync. The backend keeps '
          'a copy of the current data first.',
      action: 'Restore',
    );
    if (!ok) return;
    setState(() => _working = true);
    final sync = ref.read(categorySyncProvider.notifier);
    try {
      // First, so the backend has this phone's latest edits (they go into its safety copy).
      await sync.syncNow();
      final result = await ref.read(backupsApiProvider).restoreAppData(backup);
      await sync.syncNow();
      ref.read(categoryMemoryRevisionProvider.notifier).state++;
      _log.info('App data restored', {'file': backup.file});
      _snack('Restored: ${result.mappings} remembered payees.');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportLocal() async {
    setState(() => _working = true);
    try {
      final bytes = await exportAppDataFile(ref.read(appDatabaseProvider), appVersion: _appVersion);
      final name = 'actual-app-data-${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.json.gz';
      _log.info('Exporting app data');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: 'application/gzip')],
          fileNameOverrides: [name],
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importLocal() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !mounted) return;
    final ok = await _confirm(
      title: 'Import app data?',
      message:
          "This phone's categories, category memory and own accounts and transactions are replaced by the file's. "
          '${_hasBackend ? 'The backend and your other phones get it on the next sync.' : ''}',
      action: 'Import',
    );
    if (!ok) return;
    try {
      final result = await importAppDataFile(ref.read(appDatabaseProvider), bytes);
      ref.read(categoryMemoryRevisionProvider.notifier).state++;
      _log.info('App data imported', {
        'mappings': result.mappings,
        'accounts': result.accounts,
        'transactions': result.transactions,
        'skipped': result.skipped,
      });
      _snack(
        'Imported: ${result.accounts} accounts, ${result.transactions} transactions and '
        '${result.mappings} remembered payees'
        '${result.skipped == 0 ? '' : ', ${result.skipped} skipped'}.',
      );
    } on AppDataFileException catch (e) {
      _snack(e.message);
    }
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return result == true;
  }

  void _howToRestore() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restore a budget', style: context.text.titleLarge),
              const SizedBox(height: Space.md),
              const Text(
                '1. Share the backup to a computer.\n'
                '2. In Actual, open the budget list and choose Import file → Actual.\n'
                '3. Pick the .zip file.\n\n'
                'Actual adds it as a new budget, next to the current one; nothing is overwritten. '
                'Switch to it in Settings when you’re happy with it.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBackend = ref.watch(appConfigProvider).backendUrl?.isNotEmpty == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Backups')),
      body: RefreshIndicator(
        onRefresh: hasBackend ? _load : () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
          children: [
            if (hasBackend) ..._backendSection(context),
            _SectionTitle(hasBackend ? 'On this phone' : 'App data'),
            Text(
              hasBackend
                  ? 'A file with the categories, category memory and own accounts and transactions on this phone, '
                        "to keep or move by hand. It isn't encrypted, so keep it somewhere safe."
                  : 'Without a backend there are no scheduled backups. Export your categories, category memory, '
                        "accounts and transactions to a file you keep, and import it on a new phone. It isn't "
                        'encrypted, so keep it somewhere safe.',
              style: _muted(context),
            ),
            const SizedBox(height: Space.lg),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _working ? null : _exportLocal,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Export app data'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : _importLocal,
                  icon: const Icon(Icons.file_open_outlined, size: 18),
                  label: const Text('Import app data'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _backendSection(BuildContext context) {
    final status = _status;
    if (_error != null) {
      return [
        SizedBox(
          height: 320,
          child: ErrorRetry(title: 'Could not load the backups', message: _error!, onRetry: _load),
        ),
      ];
    }
    if (status == null) return const [SkeletonRows(count: 4, padding: EdgeInsets.zero), SizedBox(height: Space.xxl)];

    final settings = status.settings;
    final config = ref.watch(appConfigProvider);
    final currentBudget = config.budgetSyncId;
    final scheduled = currentBudget != null && settings.budgets.any((b) => b.syncId == currentBudget);

    return [
      const _SectionTitle('Schedule'),
      Text(
        'The backend backs up the app data and, with Actual connected, your budget. It keeps the newest '
        '${settings.keep}.',
        style: _muted(context),
      ),
      const SizedBox(height: Space.lg),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final f in BackupFrequency.values)
            ChoiceChip(
              label: Text(_frequencyLabel(f)),
              selected: settings.frequency == f,
              onSelected: (_) => _saveSettings(frequency: f),
            ),
        ],
      ),
      const SizedBox(height: Space.sm),
      ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: settings.frequency != BackupFrequency.off,
        title: const Text('Time'),
        subtitle: const Text("On the backend's clock"),
        trailing: Text(settings.time, style: figures(context.text.titleMedium)),
        onTap: () => _pickTime(settings.time),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Keep'),
        subtitle: const Text('Backups of each kind'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Keep fewer',
              onPressed: settings.keep > 1 ? () => _saveSettings(keep: settings.keep - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 32,
              child: Text('${settings.keep}', textAlign: TextAlign.center, style: figures(context.text.titleMedium)),
            ),
            IconButton(
              tooltip: 'Keep more',
              onPressed: settings.keep < 365 ? () => _saveSettings(keep: settings.keep + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
      if (status.actualConfigured && currentBudget != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Back up "${config.budgetName ?? 'this budget'}"'),
          subtitle: const Text('As the zip Actual’s own Export makes'),
          value: scheduled,
          onChanged: (on) => _toggleBudget(settings, currentBudget, config.budgetName, on),
        ),
      const SizedBox(height: Space.lg),
      BusyButton(label: 'Back up now', busy: _running, onPressed: _working ? null : _runNow),
      const SizedBox(height: Space.xxl),
      _TargetSection(
        title: 'App data',
        target: status.appData,
        busy: _working,
        onShare: _share,
        onDelete: _delete,
        onRestore: _restore,
      ),
      for (final b in status.budgets)
        _TargetSection(
          title: b.name ?? (b.folder == currentBudget ? (config.budgetName ?? 'Budget') : 'Budget ${b.folder}'),
          target: b,
          busy: _working,
          onShare: _share,
          onDelete: _delete,
          onHowToRestore: _howToRestore,
          onGivePassword: b.last?.errorCode == 'BUDGET_PASSWORD_REQUIRED' ? () => _givePassword(settings, b) : null,
        ),
    ];
  }
}

TextStyle? _muted(BuildContext context) => context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);

String _frequencyLabel(BackupFrequency f) => switch (f) {
  BackupFrequency.off => 'Off',
  BackupFrequency.daily => 'Daily',
  BackupFrequency.weekly => 'Weekly',
  BackupFrequency.monthly => 'Monthly',
  BackupFrequency.yearly => 'Yearly',
};

String _when(DateTime at) => DateFormat('d MMM y, HH:mm').format(at);

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _mimeType(String file) => file.endsWith('.zip') ? 'application/zip' : 'application/gzip';

class _TargetSection extends StatelessWidget {
  final String title;
  final BackupTarget target;
  final bool busy;
  final ValueChanged<BackupFile> onShare;
  final ValueChanged<BackupFile> onDelete;
  final ValueChanged<BackupFile>? onRestore;
  final VoidCallback? onHowToRestore;
  final VoidCallback? onGivePassword;

  const _TargetSection({
    required this.title,
    required this.target,
    required this.busy,
    required this.onShare,
    required this.onDelete,
    this.onRestore,
    this.onHowToRestore,
    this.onGivePassword,
  });

  @override
  Widget build(BuildContext context) {
    final last = target.last;
    final lines = [
      if (last?.lastSuccessAt != null) 'Last backup ${_when(last!.lastSuccessAt!)}' else 'No backup yet',
      if (target.nextDue != null) 'next ${_when(target.nextDue!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: Space.xs),
          Text(lines.join(' · '), style: _muted(context)),
          if (last != null && last.failed) ...[
            const SizedBox(height: Space.md),
            InlineNote(message: last.errorMessage!, tone: NoteTone.error),
            if (onGivePassword != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: onGivePassword, child: const Text('Give the backend the password')),
              ),
          ],
          const SizedBox(height: Space.sm),
          if (target.backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Text('No backups kept.', style: context.text.bodySmall),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: Radii.controlAll,
                border: Border.all(color: context.colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, b) in target.backups.indexed) ...[
                    if (i > 0) const Divider(),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: Space.lg, right: Space.xs),
                      title: Text(_when(b.createdAt), style: figures(context.text.bodyLarge)),
                      subtitle: Text([_size(b.size), if (b.beforeRestore) 'before a restore'].join(' · ')),
                      trailing: PopupMenuButton<VoidCallback>(
                        enabled: !busy,
                        tooltip: 'Actions for the backup from ${_when(b.createdAt)}',
                        onSelected: (action) => action(),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: () => onShare(b), child: const Text('Share')),
                          if (onRestore != null)
                            PopupMenuItem(value: () => onRestore!(b), child: const Text('Restore')),
                          if (onHowToRestore != null)
                            PopupMenuItem(value: onHowToRestore!, child: const Text('How to restore')),
                          PopupMenuItem(value: () => onDelete(b), child: const Text('Delete')),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Text(text, style: context.text.titleLarge),
    );
  }
}
