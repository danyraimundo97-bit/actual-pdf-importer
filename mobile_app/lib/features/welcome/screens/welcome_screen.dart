import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../review/widgets/transaction_row.dart';

/// First screen of a fresh install. The visual is the product itself: a
/// small statement whose lines arrive one by one and pick up categories,
/// which is what the app does to a real PDF.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  static final _sample = [
    ParsedTransaction(
      date: DateTime(2026, 9, 2),
      payee: 'Pingo Doce Telheiras',
      amountCents: -4237,
      rawLine: '',
      importedId: 'w1',
      suggestedCategoryId: 'c1',
      suggestedCategoryName: 'Groceries',
    ),
    ParsedTransaction(
      date: DateTime(2026, 9, 3),
      payee: 'Salary September',
      amountCents: 184350,
      rawLine: '',
      importedId: 'w2',
      suggestedCategoryId: 'c2',
      suggestedCategoryName: 'Income',
    ),
    ParsedTransaction(
      date: DateTime(2026, 9, 3),
      payee: 'EDP Comercial',
      amountCents: -6418,
      rawLine: '',
      importedId: 'w3',
      suggestedCategoryId: 'c3',
      suggestedCategoryName: 'Electricity',
    ),
  ];

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

  /// Fades and lifts a child in during [begin]..[end] of the timeline.
  Widget _enter(double begin, double end, Widget child, {double dy = 16}) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, dy * (1 - curve.value)), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.xxl,
                    Space.gutter,
                    Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _enter(
                        0,
                        0.3,
                        // Debug builds only: long-press the title for the dev page.
                        GestureDetector(
                          onLongPress: kDebugMode ? () => context.push('/dev') : null,
                          child: Text(
                            'Your bank statements, straight into Actual.',
                            style: context.text.headlineMedium?.copyWith(
                              fontSize: 34,
                              height: 1.1,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      _enter(
                        0.1,
                        0.4,
                        Text(
                          'Add a PDF, check the lines, import. Categories are remembered '
                          'for next time.',
                          style: context.text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: Space.xxl + Space.sm),
                      _StatementPreview(
                        controller: _controller,
                        transactions: _sample,
                        enter: _enter,
                      ),
                      const SizedBox(height: Space.xxl),
                      // Pushes the button to the bottom on tall screens.
                      const Spacer(),
                      _enter(
                        0.75,
                        1,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PressScale(
                              child: FilledButton(
                                onPressed: () => context.go('/setup'),
                                child: const Text('Get started'),
                              ),
                            ),
                            const SizedBox(height: Space.md),
                            Text(
                              'Needs the importer backend running on your network.',
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatementPreview extends StatelessWidget {
  final AnimationController controller;
  final List<ParsedTransaction> transactions;
  final Widget Function(double begin, double end, Widget child, {double dy}) enter;

  const _StatementPreview({
    required this.controller,
    required this.transactions,
    required this.enter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return enter(
      0.2,
      0.45,
      dy: 24,
      Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Radii.sheet),
          border: Border.all(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18, color: colors.primary),
                    const SizedBox(width: Space.sm),
                    Text('extrato_setembro.pdf', style: context.text.labelLarge),
                  ],
                ),
              ),
              // Lines arrive one after another, like a statement being read.
              for (var i = 0; i < transactions.length; i++)
                enter(
                  0.4 + i * 0.12,
                  0.62 + i * 0.12,
                  dy: 10,
                  TransactionRow(
                    transaction: transactions[i],
                    onTap: () {},
                    onToggleInclude: () {},
                  ),
                ),
              const SizedBox(height: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scales its child down slightly while pressed, as tactile feedback.
class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
