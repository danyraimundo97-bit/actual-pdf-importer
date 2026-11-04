import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/collections.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/format/banks.dart';
import '../../../core/format/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/import_history_store.dart';
import '../../../data/models/actual_account.dart';
import '../../../data/models/import_result.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/privacy_banner.dart';
import '../../../shared/widgets/sheet_body.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/connect_actual_state.dart';
import '../../review/screens/review_screen_args.dart';
import '../../categories/screens/match_categories_screen.dart';
import '../inbox_controller.dart';
import '../../../core/log/app_log.dart';

const _log = AppLog('import');

/// The Import tab: an inbox of statements. PDFs are added by picking (one
/// or several) or by sharing them from another app (see AppShell); each is
/// parsed in turn, then reviewed and imported on its own.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<ActualAccount> _accounts = [];
  bool _loadingAccounts = true;
  String? _accountsError;

  /// Actual isn't connected (it's optional): statements can still be read,
  /// but there's no account to import into yet.
  bool _actualMissing = false;
  ActualAccount? _selectedAccount;
  String? _pickError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
      _accountsError = null;
      _actualMissing = false;
    });
    final config = ref.read(appConfigProvider);
    if (config.backendUrl?.isNotEmpty != true) {
      // No backend (it's optional): nothing to import into, but statements
      // are still read and reviewed on the phone.
      setState(() {
        _actualMissing = true;
        _loadingAccounts = false;
      });
      return;
    }
    final budgetSyncId = config.budgetSyncId;
    try {
      final accounts = await ref.read(importerApiProvider).getAccounts(budgetSyncId: budgetSyncId);
      final openAccounts = accounts.where((a) => !a.closed).toList();
      final lastId = ref.read(settingsStoreProvider).lastAccountId;
      if (!mounted) return;
      setState(() {
        _accounts = openAccounts;
        _selectedAccount =
            firstWhereOrNull(openAccounts, (a) => a.id == lastId) ??
            (openAccounts.isNotEmpty ? openAccounts.first : null);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (isActualNotConnected(e)) {
        setState(() => _actualMissing = true);
        return;
      }
      setState(
        () => _accountsError = e.isUnauthorized
            ? 'The importer rejected the access token. Check it in Settings.'
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    final inbox = ref.read(inboxProvider.notifier);
    var unreadable = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        unreadable++;
        continue;
      }
      inbox.add(filename: file.name, bytes: bytes);
    }
    setState(() {
      _pickError = unreadable == 0
          ? null
          : 'Could not read $unreadable of the chosen file${unreadable == 1 ? '' : 's'}.';
    });
  }

  Future<void> _chooseAccount() async {
    final chosen = await showModalBottomSheet<ActualAccount>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AccountSheet(accounts: _accounts, selected: _selectedAccount),
    );
    if (chosen != null) setState(() => _selectedAccount = chosen);
  }

  Future<void> _unlock(InboxItem item) async {
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PasswordSheet(item: item),
    );
    if (password != null && password.isNotEmpty) {
      ref.read(inboxProvider.notifier).retry(item.id, password: password);
    }
  }

  /// The one path where a statement leaves the phone while on-device
  /// parsing is on, so it asks first.
  Future<void> _sendToBackend(InboxItem item) async {
    final backend = ref.read(backendConfigProvider).valueOrNull;
    final cloud = backend != null && backend.usesAi
        ? ' Your backend may forward it to ${backend.aiProvider ?? 'its AI provider'} to read it.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this statement to your backend?'),
        content: Text(
          'The phone could not read "${item.filename}", so this sends the PDF to your importer '
          'backend to try.$cloud It is not kept there.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed == true) ref.read(inboxProvider.notifier).sendToBackend(item.id);
  }

  Future<void> _review(InboxItem item) async {
    // No account (Actual not connected, no backend): Review still opens,
    // for CSV export.
    final account = _selectedAccount;
    final parsed = item.parseResult;
    if (parsed == null) return;
    final config = ref.read(appConfigProvider);
    final result = await context.push<ImportResult>(
      '/review',
      extra: ReviewScreenArgs(
        parseResult: parsed,
        account: account,
        budgetSyncId: config.budgetSyncId,
      ),
    );
    if (result == null || account == null) return;
    ref.read(inboxProvider.notifier).markImported(item.id, result);
    await ref.read(settingsStoreProvider).setLastAccountId(account.id);
    await ref
        .read(importHistoryProvider.notifier)
        .add(
          ImportHistoryEntry(
            filename: item.filename,
            bankId: parsed.bankId,
            accountName: account.name,
            added: result.added,
            updated: result.updated,
            at: DateTime.now(),
            accountId: account.id,
            budgetSyncId: config.budgetSyncId,
            addedIds: result.addedIds,
          ),
        );
    ref.invalidate(dashboardProvider);
    // The import remembered each payee's category on the backend.
    ref.read(categoryMemoryRevisionProvider.notifier).state++;
  }

  /// Soft-deletes the transactions one import added, after confirmation:
  /// they stay in Actual at 0.00 with a note. Uses the budget the import went
  /// into, not the currently selected one.
  Future<void> _undo(ImportHistoryEntry entry) async {
    final count = entry.addedIds.length;
    final noun = count == 1 ? 'transaction' : 'transactions';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this import?'),
        content: Text(
          'The $count $noun that "${entry.filename}" added to ${entry.accountName} will be set to '
          '0.00 in Actual, with a note saying they were removed by this app. Nothing is deleted, '
          'and transactions that were already there before are not touched.\n\n'
          'Importing the same statement again will not bring them back.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final outcome = await ref
          .read(importerApiProvider)
          .undoImport(
            accountId: entry.accountId!,
            transactionIds: entry.addedIds,
            budgetSyncId: entry.budgetSyncId,
          );
      _log.info('Import removed', {
        'accountId': entry.accountId,
        'removed': outcome.removed,
        'skipped': outcome.skipped,
      });
      await ref.read(importHistoryProvider.notifier).markUndone(entry);
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      final skipped = outcome.skipped == 0
          ? ''
          : ' ${outcome.skipped} were already removed or no longer in Actual.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${outcome.removed} $noun.$skipped')),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backendConfig = ref.watch(backendConfigProvider).valueOrNull;
    final budgetName = ref.watch(appConfigProvider).budgetName;
    final items = ref.watch(inboxProvider);
    final history = ref.watch(importHistoryProvider);
    final parseOnDevice = ref.watch(parseOnDeviceProvider);
    final pendingMatches = ref.watch(pendingCategoryMatchesProvider).valueOrNull ?? 0;
    final hasBackend = ref.watch(appConfigProvider).backendUrl?.isNotEmpty ?? false;
    final hasFinished = items.any(
      (i) => i.status == InboxStatus.imported || i.status == InboxStatus.failed,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xxl),
          children: [
            Text('Import statements', style: context.text.headlineMedium),
            if (budgetName != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                'Into $budgetName',
                style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: Space.xl),
            // With on-device parsing a statement reaches the AI provider only
            // through the "Send to backend" confirmation, which says so itself.
            if (backendConfig != null && backendConfig.usesAi && !parseOnDevice) ...[
              PrivacyBanner(providerName: backendConfig.aiProvider ?? 'an AI provider'),
              const SizedBox(height: Space.xl),
            ],
            if (pendingMatches > 0) ...[
              InlineNote(
                message:
                    '$pendingMatches ${pendingMatches == 1 ? 'category' : 'categories'} the app learned '
                    'before Actual was connected ${pendingMatches == 1 ? 'needs' : 'need'} an Actual category.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/match-categories'),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Match your categories'),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            LabeledField(label: 'Account', child: _buildAccountField()),
            const SizedBox(height: Space.xl),
            LabeledField(
              label: 'Statements',
              child: _AddZone(compact: items.isNotEmpty, onTap: _pickFiles),
            ),
            if (_pickError != null) ...[
              const SizedBox(height: Space.md),
              InlineNote(message: _pickError!, tone: NoteTone.error),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: _InboxTile(
                    item: item,
                    canReview: !_loadingAccounts,
                    onReview: () => _review(item),
                    onUnlock: () => _unlock(item),
                    onRetry: () => ref.read(inboxProvider.notifier).retry(item.id),
                    onSendToBackend: hasBackend && (backendConfig?.readsStatements ?? true)
                        ? () => _sendToBackend(item)
                        : null,
                    onRemove: () => ref.read(inboxProvider.notifier).remove(item.id),
                  ),
                ),
              if (hasFinished)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ref.read(inboxProvider.notifier).clearFinished(),
                    child: const Text('Clear finished'),
                  ),
                ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: Space.xxl),
              Text('Recent imports', style: context.text.titleLarge),
              const SizedBox(height: Space.sm),
              for (final entry in history.take(6))
                _HistoryRow(entry: entry, onUndo: entry.canUndo ? () => _undo(entry) : null),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountField() {
    if (_loadingAccounts) {
      return const Skeleton(height: 52, radius: Radii.control);
    }
    if (_actualMissing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InlineNote(
            message: 'Connect Actual to import: statements are read and reviewed here, '
                'then go into one of your Actual accounts.',
          ),
          const SizedBox(height: Space.xs),
          TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Connect Actual'),
          ),
        ],
      );
    }
    if (_accountsError != null || _accounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineNote(
            message:
                _accountsError ??
                'This budget has no open accounts. Add one in Actual, then refresh.',
            tone: _accountsError != null ? NoteTone.error : NoteTone.neutral,
          ),
          const SizedBox(height: Space.xs),
          TextButton.icon(
            onPressed: _loadAccounts,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh accounts'),
          ),
        ],
      );
    }
    final account = _selectedAccount;
    return PickerField(
      leadingIcon: Icons.account_balance_outlined,
      value: account?.name ?? 'Choose an account',
      isPlaceholder: account == null,
      onTap: _chooseAccount,
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Big when the inbox is empty (it is the screen's main action), a slim
/// row once statements are queued so the list gets the space.
class _AddZone extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;

  const _AddZone({required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.controlAll,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: compact ? Space.md : Space.xl,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 52,
                height: compact ? 40 : 52,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: Radii.controlAll,
                ),
                child: Icon(
                  compact ? Icons.add_rounded : Icons.picture_as_pdf_outlined,
                  size: compact ? 22 : 26,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(compact ? 'Add more PDFs' : 'Add PDFs', style: context.text.titleMedium),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Pick one or several, or share them here from your bank's app.",
                        style: context.text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  final InboxItem item;
  final bool canReview;
  final VoidCallback onReview;
  final VoidCallback onUnlock;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  /// Null without a backend: an unrecognised statement then has nowhere
  /// else to go.
  final VoidCallback? onSendToBackend;

  const _InboxTile({
    required this.item,
    required this.canReview,
    required this.onReview,
    required this.onUnlock,
    required this.onRetry,
    required this.onRemove,
    this.onSendToBackend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = item.parseResult?.transactions.length ?? 0;
    final imported = item.importResult;

    final (Widget leading, String status, Color statusColor) = switch (item.status) {
      InboxStatus.queued => (
        Icon(Icons.schedule_rounded, color: colors.onSurfaceVariant),
        'Waiting',
        colors.onSurfaceVariant,
      ),
      InboxStatus.parsing => (
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
        ),
        'Reading statement',
        colors.onSurfaceVariant,
      ),
      InboxStatus.needsPassword => (
        Icon(Icons.lock_outline_rounded, color: colors.primary),
        item.wrongPassword ? 'Wrong password. Try again.' : 'Locked with a password',
        item.wrongPassword ? colors.error : colors.onSurfaceVariant,
      ),
      InboxStatus.unrecognized => (
        Icon(Icons.help_outline_rounded, color: colors.onSurfaceVariant),
        switch ((item.recognizedBank, onSendToBackend != null)) {
          (final bank?, _) =>
            'Looks like ${bankDisplayName(bank)}, but no transactions were found. '
                'The statement layout may have changed.',
          (null, true) => "This bank can't be read on the phone yet. Your backend's AI parser can try.",
          (null, false) => "This bank can't be read on the phone yet.",
        },
        colors.onSurfaceVariant,
      ),
      InboxStatus.ready => (
        Icon(Icons.description_outlined, color: colors.primary),
        '$count transaction${count == 1 ? '' : 's'} from '
            '${bankDisplayName(item.parseResult!.bankId)}',
        colors.onSurfaceVariant,
      ),
      InboxStatus.imported => (
        Icon(Icons.check_circle_rounded, color: context.tokens.inflow),
        'Imported: ${imported?.added ?? 0} added, ${imported?.updated ?? 0} already in Actual',
        colors.onSurfaceVariant,
      ),
      InboxStatus.failed => (
        Icon(Icons.error_outline_rounded, color: colors.error),
        item.error ?? 'Could not read this statement.',
        colors.error,
      ),
    };

    final Widget? action = switch (item.status) {
      InboxStatus.ready => FilledButton(
        onPressed: canReview ? onReview : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text('Review'),
      ),
      InboxStatus.needsPassword => OutlinedButton(
        onPressed: onUnlock,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text('Unlock'),
      ),
      InboxStatus.failed => TextButton(onPressed: onRetry, child: const Text('Retry')),
      InboxStatus.unrecognized when onSendToBackend != null => OutlinedButton(
        onPressed: onSendToBackend,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text('Send to backend'),
      ),
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.xs, Space.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: Radii.controlAll,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: leading)),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: statusColor),
                ),
                Text(_formatFileSize(item.sizeBytes), style: figures(context.text.bodySmall)),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: Space.sm), action],
          if (item.status != InboxStatus.parsing)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onRemove,
            )
          else
            const SizedBox(width: Space.md),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ImportHistoryEntry entry;

  /// Null when the entry can't be removed (already removed, or saved before
  /// removing existed).
  final VoidCallback? onUndo;

  const _HistoryRow({required this.entry, this.onUndo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${bankDisplayName(entry.bankId)} into ${entry.accountName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.undoneAt != null ? 'Removed' : '+${entry.added}',
                style: figures(context.text.bodyMedium).copyWith(
                  color: entry.undoneAt != null ? context.colors.onSurfaceVariant : null,
                ),
              ),
              Text(formatDisplayDate(entry.at), style: figures(context.text.bodySmall)),
            ],
          ),
          if (onUndo != null)
            IconButton(
              icon: const Icon(Icons.undo_rounded, size: 20),
              tooltip: 'Remove this import',
              visualDensity: VisualDensity.compact,
              onPressed: onUndo,
            ),
        ],
      ),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  final InboxItem item;

  const _PasswordSheet({required this.item});

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'This statement is locked',
      description: 'Many banks use your NIF or card number as the password.',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Unlock'),
        ),
      ],
      children: [
        LabeledField(
          label: 'Password for ${widget.item.filename}',
          child: TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              errorText: widget.item.wrongPassword ? 'That password was incorrect.' : null,
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ),
      ],
    );
  }
}

class _AccountSheet extends StatelessWidget {
  final List<ActualAccount> accounts;
  final ActualAccount? selected;

  const _AccountSheet({required this.accounts, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
              child: Text('Import into', style: context.text.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: Space.lg),
                children: [
                  for (final account in accounts)
                    ListTile(
                      leading: const Icon(Icons.account_balance_outlined),
                      title: Text(account.name),
                      subtitle: account.offbudget ? const Text('Off-budget') : null,
                      selected: account.id == selected?.id,
                      trailing: account.id == selected?.id
                          ? Icon(Icons.check_rounded, color: colors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, account),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
