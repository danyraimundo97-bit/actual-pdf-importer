import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../widgets/actual_step.dart';

/// The setup guide, nothing required: how the app works, then connecting to
/// Actual, offered as the last step ("Bring your budget along"). The backend
/// and Actual are both optional (docs/plans/core-app.md), so the guide ends
/// on that page whether or not anything was connected.
class SetupScreen extends ConsumerStatefulWidget {
  /// Step to open on (0-[lastStep]). The dev page uses it to jump straight in.
  final int initialStep;

  static const lastStep = 1;

  const SetupScreen({super.key, this.initialStep = 0});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _stepCount = SetupScreen.lastStep + 1;
  static const _titles = ['How it works', 'Bring your budget along'];

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
  }

  @override
  void dispose() {
    _pages.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(step, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  /// Ends the guide: on Home with a budget, otherwise on Import (what works
  /// without Actual), saying where to connect later.
  Future<void> _finish({required bool connected}) async {
    await ref.read(appConfigProvider.notifier).setOnboarded(true);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.go(connected ? '/dashboard' : '/import');
    if (!connected) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can connect Actual any time in Settings → Connection.')),
      );
    }
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
          leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
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
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
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
                  _HowItWorksStep(onNext: () => _goTo(1)),
                  ActualStep(
                    urlController: _urlController,
                    tokenController: _tokenController,
                    onFinish: _finish,
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

class _HowItWorksStep extends StatelessWidget {
  final VoidCallback onNext;

  const _HowItWorksStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      action: BusyButton(label: 'Continue', onPressed: onNext),
      children: const [
        _Fact(
          icon: Icons.ios_share_rounded,
          title: 'Statements in, from anywhere',
          body: 'Share a PDF straight from your bank app, or pick a few at once. '
              'ActivoBank, Moey and Trade Republic are read by built-in parsers.',
        ),
        _Fact(
          icon: Icons.fact_check_outlined,
          title: 'You check every line',
          body: 'Nothing is imported until you have reviewed it. Fix a payee, a date or an amount '
              'before it goes anywhere.',
        ),
        _Fact(
          icon: Icons.sell_outlined,
          title: 'Categories that learn',
          body: 'Categorise a payee once and it is suggested the next time it shows up.',
        ),
        _Fact(
          icon: Icons.lock_outline_rounded,
          title: 'Private by default',
          body: 'Statements are read in memory and never stored. They only reach an AI service '
              'if you turn that on in the backend.',
        ),
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
