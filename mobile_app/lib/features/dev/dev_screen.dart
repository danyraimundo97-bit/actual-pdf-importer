import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/actual_account.dart';
import '../../data/models/parse_result.dart';
import '../../data/models/parsed_transaction.dart';
import '../../data/providers.dart';
import '../../shared/widgets/inline_note.dart';
import '../review/screens/review_screen_args.dart';

/// Values baked in with `flutter run --dart-define-from-file=dev.json`
/// (see dev.example.json). Empty when not provided.
class DevPreset {
  static const backendUrl = String.fromEnvironment('DEV_BACKEND_URL');
  static const token = String.fromEnvironment('DEV_TOKEN');
  static const budgetSyncId = String.fromEnvironment('DEV_BUDGET_SYNC_ID');
  static const budgetName = String.fromEnvironment('DEV_BUDGET_NAME');

  static bool get isComplete => backendUrl.isNotEmpty && budgetSyncId.isNotEmpty;
}

/// Debug builds only (the route is not registered in release, see
/// core/router.dart). Opened by long-pressing the title on Welcome or
/// Settings.
class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  Future<void> _applyPreset(BuildContext context, WidgetRef ref) async {
    final config = ref.read(appConfigProvider.notifier);
    await config.setBackendUrl(DevPreset.backendUrl);
    await ref.read(secretStoreProvider).setApiToken(DevPreset.token);
    await config.setBudget(
      DevPreset.budgetSyncId,
      DevPreset.budgetName.isEmpty ? 'Dev budget' : DevPreset.budgetName,
    );
    await config.setOnboarded(true);
    if (context.mounted) context.go('/dashboard');
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe everything?'),
        content: const Text(
          'Clears the connection, token, budget and statement passwords and import history. '
          'The app starts again from the welcome screen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wipe')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(secretStoreProvider).clearAll();
    await ref.read(appConfigProvider.notifier).reset();
    ref.read(importHistoryProvider.notifier).reload();
    if (context.mounted) context.go('/welcome');
  }

  Future<void> _replayWelcome(BuildContext context, WidgetRef ref) async {
    await ref.read(appConfigProvider.notifier).setOnboarded(false);
    if (context.mounted) context.go('/welcome');
  }

  ReviewScreenArgs _sampleReview(String? budgetSyncId) {
    ParsedTransaction tx(String date, String payee, int cents, [String? category]) =>
        ParsedTransaction(
          date: DateTime.parse(date),
          payee: payee,
          amountCents: cents,
          rawLine: '$date  $payee  ${(cents / 100).toStringAsFixed(2)}',
          importedId: 'dev-$payee',
          suggestedCategoryId: category == null ? null : 'dev-$category',
          suggestedCategoryName: category,
        );
    return ReviewScreenArgs(
      parseResult: ParseResult(
        bankId: 'activobank',
        transactions: [
          tx('2026-09-02', 'Pingo Doce Telheiras', -4237, 'Groceries'),
          tx('2026-09-02', 'Uber Trip Lisboa', -812),
          tx('2026-09-03', 'Salary September', 184350, 'Income'),
          tx('2026-09-05', 'EDP Comercial', -6418, 'Electricity'),
        ],
      ),
      account: const ActualAccount(
        id: 'dev-account',
        name: 'Dev account',
        offbudget: false,
        closed: false,
      ),
      budgetSyncId: budgetSyncId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final muted = context.text.bodySmall;

    // Tabs are switched with go (they live in the shell); full-screen
    // routes are pushed so Back returns here.
    Widget jump(String label, String location, {Object? extra, bool tab = false}) => OutlinedButton(
      onPressed: () => tab ? context.go(location) : context.push(location, extra: extra),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
      child: Text(label),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          Text('Current state', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          _KeyValue('Backend', config.backendUrl ?? 'not set'),
          _KeyValue(
            'Budget',
            config.budgetName == null ? 'not set' : '${config.budgetName} (${config.budgetSyncId})',
          ),
          _KeyValue('Onboarded', config.onboarded ? 'yes' : 'no'),
          const SizedBox(height: Space.xxl),
          Text('Preset connection', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          if (DevPreset.isComplete) ...[
            _KeyValue('Backend', DevPreset.backendUrl),
            _KeyValue(
              'Budget',
              DevPreset.budgetName.isEmpty ? DevPreset.budgetSyncId : DevPreset.budgetName,
            ),
            _KeyValue('Token', DevPreset.token.isEmpty ? 'none' : 'set'),
            const SizedBox(height: Space.md),
            FilledButton.icon(
              onPressed: () => _applyPreset(context, ref),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Apply preset and open dashboard'),
            ),
          ] else
            const InlineNote(
              message:
                  'No preset found. Copy dev.example.json to dev.json, fill it in, and run '
                  'flutter run --dart-define-from-file=dev.json',
            ),
          const SizedBox(height: Space.xxl),
          Text('Reset', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => _replayWelcome(context, ref),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Replay welcome'),
              ),
              OutlinedButton.icon(
                onPressed: () => _wipe(context, ref),
                icon: Icon(Icons.delete_forever_outlined, size: 18, color: context.colors.error),
                label: Text('Wipe everything', style: TextStyle(color: context.colors.error)),
              ),
            ],
          ),
          const SizedBox(height: Space.xxl),
          Text('Jump to', style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            'Full-screen pages open directly. The tabs still need a finished setup, '
            'so apply the preset first.',
            style: muted,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              jump('Welcome', '/welcome'),
              for (var step = 0; step < 4; step++) jump('Setup ${step + 1}', '/setup?step=$step'),
              jump('Dashboard', '/dashboard', tab: true),
              jump('Import', '/import', tab: true),
              jump('Memory', '/categories', tab: true),
              jump('Settings', '/settings', tab: true),
              jump('Review (sample)', '/review', extra: _sampleReview(config.budgetSyncId)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: context.text.bodySmall)),
          Expanded(child: SelectableText(value, style: figures(context.text.bodyMedium))),
        ],
      ),
    );
  }
}
