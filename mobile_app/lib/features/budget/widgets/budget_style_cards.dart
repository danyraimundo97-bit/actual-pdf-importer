import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/ledger_builders.dart';
import '../../../shared/widgets/pressable.dart';

/// The name people see. Actual calls the first one "tracking".
String budgetStyleName(BudgetStyle style) => switch (style) {
  BudgetStyle.tracking => 'Simple monthly limits',
  BudgetStyle.envelope => 'Envelopes',
};

// The guide's one example (docs/plans/local-ledger.md), in the app's own money
// format. Illustrative, not the user's numbers.
const _limit = 30000;
const _spent = 25000;

/// The example both cards answer.
class BudgetStyleExample extends StatelessWidget {
  const BudgetStyleExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Say 🛒 Groceries is set to ${formatBalance(_limit)} a month, and in October you spend ${formatBalance(_spent)}. '
      'What happens to the rest?',
      style: context.text.bodyLarge,
    );
  }
}

/// One style, explained through the example. With [onTap] it's a choice among
/// the others; without, a plain explanation. [detailed] adds overspending and
/// "To budget", for the guide.
class BudgetStyleCard extends StatelessWidget {
  final BudgetStyle style;
  final bool selected;
  final VoidCallback? onTap;
  final bool detailed;

  const BudgetStyleCard({super.key, required this.style, this.selected = false, this.onTap, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final envelope = style == BudgetStyle.envelope;
    final muted = context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    final next = envelope ? _limit + (_limit - _spent) : _limit;
    final card = AnimatedContainer(
      duration: Motion.of(context, Motion.small),
      curve: Motion.easeOut,
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        borderRadius: Radii.controlAll,
        color: selected ? colors.primary.withValues(alpha: 0.05) : null,
        border: Border.all(color: selected ? colors.primary : colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(budgetStyleName(style), style: context.text.titleSmall)),
              if (onTap != null) ...[
                const SizedBox(width: Space.sm),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            envelope
                ? 'What you don\'t spend stays in the category for next month.'
                : 'Each month starts fresh with the same limit.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: Space.md),
          _Line(label: 'October', value: '${formatBalance(_limit - _spent)} left'),
          const SizedBox(height: Space.xs),
          _Line(label: 'November holds', value: formatBalance(next), strong: true),
          if (detailed) ...[
            const SizedBox(height: Space.md),
            Text(
              envelope
                  ? 'Overspending comes out of next month\'s To budget. To budget is the income you haven\'t put in '
                        'any category yet, and it carries from month to month.'
                  : 'Overspending shows in that month only. To budget is this month\'s income minus what you budgeted '
                        'this month.',
              style: muted,
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      inMutuallyExclusiveGroup: onTap != null,
      checked: onTap != null ? selected : null,
      child: Pressable(onTap: onTap, borderRadius: Radii.controlAll, child: card),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _Line({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final small = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: Space.md,
      children: [
        Text(label, style: small),
        Text(value, style: figures(context.text.bodyMedium).copyWith(fontWeight: strong ? FontWeight.w600 : null)),
      ],
    );
  }
}

/// Both styles as a choice.
class BudgetStyleChooser extends StatelessWidget {
  final BudgetStyle? selected;
  final ValueChanged<BudgetStyle> onChanged;

  const BudgetStyleChooser({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final style in BudgetStyle.values) ...[
          if (style != BudgetStyle.values.first) const SizedBox(height: Space.md),
          BudgetStyleCard(style: style, selected: style == selected, onTap: () => onChanged(style)),
        ],
      ],
    );
  }
}
