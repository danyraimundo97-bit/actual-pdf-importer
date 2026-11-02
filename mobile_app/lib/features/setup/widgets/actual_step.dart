import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_budget.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../settings/connection_controller.dart';
import '../../settings/widgets/actual_server_card.dart';
import '../../settings/widgets/connection_widgets.dart';

/// The setup guide's last page: connecting to Actual, offered, not
/// required. Sells the connection with the product itself (statement rows
/// landing in a budget that fills up), says honestly what works without
/// it, and expands in place into the three links: backend → Actual server
/// → budget. "Not now" finishes the guide either way.
class ActualStep extends ConsumerStatefulWidget {
  final TextEditingController urlController;
  final TextEditingController tokenController;

  /// Finish the guide; [connected] = a budget was chosen.
  final Future<void> Function({required bool connected}) onFinish;

  const ActualStep({
    super.key,
    required this.urlController,
    required this.tokenController,
    required this.onFinish,
  });

  @override
  ConsumerState<ActualStep> createState() => _ActualStepState();
}

class _ActualStepState extends ConsumerState<ActualStep> {
  bool _expanded = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Running the guide again with a backend already set: show where it stands.
    if ((ref.read(appConfigProvider).backendUrl ?? '').isNotEmpty) {
      _expanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    final controller = ref.read(connectionControllerProvider.notifier);
    if (await controller.test() && ref.read(connectionControllerProvider).actualConfigured) {
      await controller.loadBudgets();
    }
  }

  Future<void> _connectBackend() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(connectionControllerProvider.notifier);
    final ok = await controller.saveAndTest(url: widget.urlController.text, token: widget.tokenController.text);
    if (ok && ref.read(connectionControllerProvider).actualConfigured) await controller.loadBudgets();
  }

  Future<void> _finish({required bool connected}) async {
    setState(() => _finishing = true);
    try {
      await widget.onFinish(connected: connected);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(connectionControllerProvider);
    final selected = ref.watch(appConfigProvider).budgetSyncId;
    final hasBudget = selected != null && check.budgets.any((b) => b.syncId == selected);
    final colors = context.colors;
    final muted = context.text.bodyLarge?.copyWith(color: colors.onSurfaceVariant);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
            children: [
              const BudgetHero(),
              const SizedBox(height: Space.xl),
              Text(
                'Connect to Actual to import statements and see your money here. '
                'You can also do this later.',
                style: muted,
              ),
              const SizedBox(height: Space.xl),
              const _WhatYouGet(),
              AnimatedSize(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_expanded
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: Space.xxl),
                          _Part(
                            number: 1,
                            title: 'Your bridge',
                            done: check.isConnected,
                            body:
                                'The app reaches Actual through backend_app, a small server you run next to '
                                'it (see INSTALL.md for the Docker setup).',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ConnectionFields(
                                  urlController: widget.urlController,
                                  tokenController: widget.tokenController,
                                  onSubmitted: _connectBackend,
                                ),
                                const SizedBox(height: Space.lg),
                                BusyButton(
                                  label: check.isConnected ? 'Connected. Test again' : 'Connect',
                                  busy: check.status == ConnectionStatus.testing,
                                  onPressed: _connectBackend,
                                ),
                                if (check.status == ConnectionStatus.failed && check.message != null) ...[
                                  const SizedBox(height: Space.md),
                                  InlineNote(message: check.message!, tone: NoteTone.error),
                                ],
                              ],
                            ),
                          ),
                          if (check.isConnected) ...[
                            const SizedBox(height: Space.xl),
                            _Part(
                              number: 2,
                              title: 'Your Actual server',
                              done: check.actualConfigured,
                              child: ActualServerCard(
                                onConnected: () => ref.read(connectionControllerProvider.notifier).loadBudgets(),
                              ),
                            ),
                          ],
                          if (check.actualConfigured) ...[
                            const SizedBox(height: Space.xl),
                            _Part(
                              number: 3,
                              title: 'Your budget',
                              done: hasBudget,
                              child: _BudgetPicker(check: check, selected: selected),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_expanded)
                  BusyButton(label: 'Connect Actual', onPressed: () => setState(() => _expanded = true))
                else
                  BusyButton(
                    label: 'Finish',
                    busy: _finishing,
                    onPressed: hasBudget ? () => _finish(connected: true) : null,
                  ),
                const SizedBox(height: Space.xs),
                TextButton(
                  onPressed: _finishing ? null : () => _finish(connected: false),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Honest two-column comparison: what Actual adds, what already works.
class _WhatYouGet extends StatelessWidget {
  const _WhatYouGet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget column(String title, IconData icon, Color color, List<String> items) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: colors.surfaceContainer, borderRadius: Radii.controlAll),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: Space.sm),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs + 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: Space.xs + 2),
                        Expanded(child: Text(item, style: context.text.bodySmall)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          column('With Actual', Icons.add_circle_outline_rounded, colors.primary, const [
            'Balances and recent transactions',
            "This month's budget",
            'Quick add',
            'Import into your accounts',
          ]),
          const SizedBox(width: Space.md),
          column('Already works', Icons.check_rounded, colors.onSurfaceVariant, const [
            'Reading your statements',
            'Reviewing every line',
            'Category memory',
          ]),
        ],
      ),
    );
  }
}

/// One numbered link in the chain, ticked when done.
class _Part extends StatelessWidget {
  final int number;
  final String title;
  final String? body;
  final bool done;
  final Widget child;

  const _Part({required this.number, required this.title, required this.done, required this.child, this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: done
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), size: 24, color: colors.primary)
                  : CircleAvatar(
                      key: const ValueKey('todo'),
                      radius: 12,
                      backgroundColor: colors.surfaceContainerHighest,
                      child: Text('$number', style: context.text.labelMedium),
                    ),
            ),
            const SizedBox(width: Space.md),
            Text(title, style: context.text.titleMedium),
          ],
        ),
        if (body != null) ...[
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.only(left: 24 + Space.md),
            child: Text(body!, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ),
        ],
        const SizedBox(height: Space.md),
        child,
      ],
    );
  }
}

class _BudgetPicker extends ConsumerWidget {
  final ConnectionCheck check;
  final String? selected;

  const _BudgetPicker({required this.check, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(connectionControllerProvider.notifier);
    if (check.budgetsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineNote(message: check.budgetsError!, tone: NoteTone.error),
          TextButton.icon(
            onPressed: controller.loadBudgets,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      );
    }
    if (!check.loadingBudgets && check.budgets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InlineNote(message: noBudgetsMessage),
          TextButton.icon(
            onPressed: controller.loadBudgets,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      );
    }
    return BudgetList(
      budgets: check.budgets,
      loading: check.loadingBudgets,
      selectedSyncId: selected,
      onSelect: (ActualBudget b) => chooseBudget(context, ref, b),
    );
  }
}

/// The page's illustration, in Welcome's visual language: three reviewed
/// statement rows slide into an Actual budget card, which then fills up (a
/// balance counts up, two category bars grow, a "To budget" chip pops in).
/// Plays once, about 1.6 s; with reduced motion it shows the end state.
class BudgetHero extends StatefulWidget {
  const BudgetHero({super.key});

  @override
  State<BudgetHero> createState() => _BudgetHeroState();
}

class _BudgetHeroState extends State<BudgetHero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  static const _rows = [
    ('Pingo Doce', -4237),
    ('Salary', 184350),
    ('EDP Comercial', -6418),
  ];
  static const _balanceCents = 124830;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Illustration: statement lines flowing into an Actual budget',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The statement rows: in, then they "drop" into the card below.
              for (var i = 0; i < _rows.length; i++)
                Builder(builder: (context) {
                  final enter = _phase(0.05 * i, 0.25 + 0.05 * i);
                  final leave = _phase(0.35 + 0.05 * i, 0.55 + 0.05 * i, Curves.easeInCubic);
                  final (payee, cents) = _rows[i];
                  return Opacity(
                    opacity: (enter * (1 - leave)).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(-24 * (1 - enter), 28.0 * leave),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.xs),
                        child: Row(
                          children: [
                            Expanded(child: Text(payee, style: context.text.bodyMedium)),
                            Text(
                              formatCents(cents),
                              style: figures(context.text.bodyMedium).copyWith(
                                color: cents > 0 ? context.tokens.inflow : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: Space.sm),
              Transform.scale(
                scale: 0.96 + 0.04 * _phase(0.4, 0.7, Curves.easeOutBack),
                child: Container(
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: Radii.controlAll,
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 18, color: colors.primary),
                          const SizedBox(width: Space.xs + 2),
                          Text('Actual', style: context.text.labelLarge?.copyWith(color: colors.primary)),
                          const Spacer(),
                          Opacity(
                            opacity: _phase(0.85, 1),
                            child: Transform.scale(
                              scale: 0.6 + 0.4 * _phase(0.85, 1, Curves.easeOutBack),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  'To budget ${formatCents(32000)}',
                                  style: figures(context.text.labelSmall).copyWith(color: colors.primary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        formatCents((_balanceCents * _phase(0.45, 0.85)).round()),
                        style: figures(context.text.headlineSmall).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: Space.md),
                      _HeroBar(label: 'Groceries', fill: 0.62 * _phase(0.55, 0.9)),
                      const SizedBox(height: Space.sm),
                      _HeroBar(label: 'Transport', fill: 0.35 * _phase(0.6, 0.95)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBar extends StatelessWidget {
  final String label;
  final double fill;

  const _HeroBar({required this.label, required this.fill});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: context.text.bodySmall)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 6,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}
