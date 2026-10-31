import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_budget.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../settings/connection_controller.dart';
import '../../settings/widgets/connection_widgets.dart';

/// Four steps from a fresh install to a working dashboard: connect to the
/// importer, confirm what it can do, pick a budget, done. Uses the same
/// ConnectionController as Settings, so both run identical checks.
class SetupScreen extends ConsumerStatefulWidget {
  /// Step to open on (0-3). The dev page uses it to jump straight in.
  final int initialStep;

  const SetupScreen({super.key, this.initialStep = 0});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _stepCount = 4;
  static const _titles = [
    'Connect to your importer',
    'Connection works',
    'Choose a budget',
    "You're all set",
  ];

  late final PageController _pages = PageController(initialPage: widget.initialStep);
  late int _step = widget.initialStep;
  late final TextEditingController _urlController;
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(appConfigProvider).backendUrl ?? '');
    ref.read(secretStoreProvider).apiToken.then((token) {
      if (mounted && token != null) _tokenController.text = token;
    });
    // Jumping in past step 1 (dev page) still needs the connection state.
    if (widget.initialStep > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFor(widget.initialStep));
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _refreshFor(int step) async {
    final controller = ref.read(connectionControllerProvider.notifier);
    if (await controller.test() && step >= 2) await controller.loadBudgets();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(
        step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(connectionControllerProvider.notifier)
        .saveAndTest(url: _urlController.text, token: _tokenController.text);
    if (ok && mounted) _goTo(1);
  }

  void _toBudgets() {
    ref.read(connectionControllerProvider.notifier).loadBudgets();
    _goTo(2);
  }

  Future<void> _finish() async {
    await ref.read(appConfigProvider.notifier).setOnboarded(true);
    if (mounted) context.go('/dashboard');
  }

  void _back() {
    if (_step == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/welcome');
      }
    } else {
      _goTo(_step - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: Text(
            'Step ${_step + 1} of $_stepCount',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: _StepIndicator(count: _stepCount, current: _step),
            ),
            const SizedBox(height: Space.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Align(
                  key: ValueKey(_step),
                  alignment: Alignment.centerLeft,
                  child: Text(_titles[_step], style: context.text.headlineMedium),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ConnectStep(
                    urlController: _urlController,
                    tokenController: _tokenController,
                    onConnect: _connect,
                  ),
                  _CheckStep(onNext: _toBudgets),
                  _BudgetStep(onNext: () => _goTo(3)),
                  _DoneStep(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented: one bar per step, filled up to the current one.
class _StepIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _StepIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: Space.xs + 2),
          Expanded(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Scrollable step body with the primary action pinned to the bottom.
class _StepLayout extends StatelessWidget {
  final List<Widget> children;
  final Widget action;

  const _StepLayout({required this.children, required this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
            children: children,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
            child: action,
          ),
        ),
      ],
    );
  }
}

class _ConnectStep extends ConsumerWidget {
  final TextEditingController urlController;
  final TextEditingController tokenController;
  final VoidCallback onConnect;

  const _ConnectStep({
    required this.urlController,
    required this.tokenController,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(connectionControllerProvider);
    final failed = check.status == ConnectionStatus.failed;
    return _StepLayout(
      action: BusyButton(
        label: 'Connect',
        busy: check.status == ConnectionStatus.testing,
        onPressed: onConnect,
      ),
      children: [
        Text(
          'The app talks to backend_app, which talks to your Actual server. Enter '
          'the address it runs on and its access token.',
          style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        ConnectionFields(
          urlController: urlController,
          tokenController: tokenController,
          onSubmitted: onConnect,
        ),
        if (failed && check.message != null) ...[
          const SizedBox(height: Space.lg),
          InlineNote(message: check.message!, tone: NoteTone.error),
        ],
      ],
    );
  }
}

class _CheckStep extends ConsumerWidget {
  final VoidCallback onNext;

  const _CheckStep({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(connectionControllerProvider);
    final config = check.config;
    final muted = context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant);
    return _StepLayout(
      action: BusyButton(label: 'Continue', onPressed: check.isConnected ? onNext : null),
      children: [
        if (check.status == ConnectionStatus.testing)
          const LinearProgressIndicator()
        else if (!check.isConnected)
          InlineNote(
            message: check.message ?? 'Not connected yet. Go back and enter the address.',
            tone: NoteTone.error,
          )
        else ...[
          InlineNote(
            message: 'The importer answered and accepted your token.',
            tone: NoteTone.success,
          ),
          const SizedBox(height: Space.xl),
          _Fact(
            icon: Icons.document_scanner_outlined,
            title: 'How statements are read',
            body: switch (config?.parserMode) {
              'regex' =>
                'Built-in parsers for ActivoBank, Moey and Trade Republic. '
                    'Nothing leaves your network.',
              'ai' => 'Every statement is read by ${config?.aiProvider ?? 'an AI provider'}.',
              _ =>
                'Built-in parsers first. Statements they do not recognise go to '
                    '${config?.aiProvider ?? 'an AI provider'}.',
            },
          ),
          if (config?.usesAi ?? false)
            _Fact(
              icon: Icons.cloud_upload_outlined,
              title: 'Privacy',
              body:
                  'With this mode, some statements leave your network. Change PARSER_MODE '
                  'in the backend .env to "regex" to keep everything local.',
            ),
          _Fact(
            icon: Icons.sell_outlined,
            title: 'Categories',
            body:
                'Suggested from payees you have categorized before. You confirm every '
                'line before anything is imported.',
          ),
          Text('Next, choose which Actual budget to import into.', style: muted),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Fact({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: context.colors.primary),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStep extends ConsumerWidget {
  final VoidCallback onNext;

  const _BudgetStep({required this.onNext});

  Future<void> _select(BuildContext context, WidgetRef ref, ActualBudget budget) async {
    await chooseBudget(context, ref, budget);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(connectionControllerProvider);
    final selected = ref.watch(appConfigProvider).budgetSyncId;
    final hasSelection = selected != null && check.budgets.any((b) => b.syncId == selected);

    return _StepLayout(
      action: BusyButton(label: 'Continue', onPressed: hasSelection ? onNext : null),
      children: [
        Text(
          'Imported transactions go into this budget. You can switch later in Settings.',
          style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        if (check.budgetsError != null) ...[
          InlineNote(message: check.budgetsError!, tone: NoteTone.error),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.read(connectionControllerProvider.notifier).loadBudgets(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ),
        ] else if (!check.loadingBudgets && check.budgets.isEmpty)
          const InlineNote(
            message: 'The Actual server has no budgets yet. Create one in Actual first.',
          )
        else
          BudgetList(
            budgets: check.budgets,
            loading: check.loadingBudgets,
            selectedSyncId: selected,
            onSelect: (b) => _select(context, ref, b),
          ),
      ],
    );
  }
}

class _DoneStep extends ConsumerWidget {
  final Future<void> Function() onFinish;

  const _DoneStep({required this.onFinish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final muted = context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant);
    return _StepLayout(
      action: BusyButton(label: 'Open dashboard', onPressed: onFinish),
      children: [
        Text(
          'Connected to ${config.backendUrl ?? 'your importer'} and importing into '
          '"${config.budgetName ?? 'your budget'}".',
          style: muted,
        ),
        const SizedBox(height: Space.xl),
        const _Fact(
          icon: Icons.insights_outlined,
          title: 'Dashboard',
          body: 'Balances, money in and out, and where it went, straight from Actual.',
        ),
        const _Fact(
          icon: Icons.inbox_outlined,
          title: 'Import',
          body: 'Add statements in bulk or share them from your bank app, then review each one.',
        ),
        const _Fact(
          icon: Icons.sell_outlined,
          title: 'Memory',
          body: 'The payee to category mappings that make suggestions better over time.',
        ),
      ],
    );
  }
}
