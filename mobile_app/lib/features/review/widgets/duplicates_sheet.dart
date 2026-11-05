import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../shared/widgets/sheet_body.dart';

typedef DuplicateQuestion = ({int index, ParsedTransaction line, String? existingPayee});

/// Asks, for each statement line with the same date and amount as a saved
/// transaction, whether it's the same one. Returns the [DuplicateQuestion.index]
/// of those that are, or null if the user backed out (nothing gets saved).
Future<Set<int>?> showDuplicatesSheet(BuildContext context, List<DuplicateQuestion> questions) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DuplicatesSheet(questions: questions),
  );
}

class _DuplicatesSheet extends StatefulWidget {
  final List<DuplicateQuestion> questions;

  const _DuplicatesSheet({required this.questions});

  @override
  State<_DuplicatesSheet> createState() => _DuplicatesSheetState();
}

class _DuplicatesSheetState extends State<_DuplicatesSheet> {
  /// Starts as "the same": adding one twice is the mistake that's hard to spot.
  late final Set<int> _same = {for (final q in widget.questions) q.index};

  @override
  Widget build(BuildContext context) {
    final count = widget.questions.length;
    final muted = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    return SheetBody(
      title: count == 1 ? 'Is this already saved?' : 'Are these already saved?',
      description: count == 1
          ? 'This account has a transaction with the same date and amount.'
          : 'This account has transactions with the same date and amount as $count of these lines.',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _same), child: const Text('Continue')),
      ],
      children: [
        for (final q in widget.questions)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(q.line.payee, maxLines: 2, style: context.text.bodyLarge)),
                    const SizedBox(width: Space.md),
                    Text(formatCents(q.line.amountCents), style: figures(context.text.bodyLarge)),
                  ],
                ),
                Text('${formatDisplayDate(q.line.date)} · Saved as: ${q.existingPayee ?? 'no payee'}', style: muted),
                const SizedBox(height: Space.sm),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Same, skip it')),
                    ButtonSegment(value: false, label: Text('Different, add it')),
                  ],
                  selected: {_same.contains(q.index)},
                  onSelectionChanged: (s) => setState(() {
                    if (s.first) {
                      _same.add(q.index);
                    } else {
                      _same.remove(q.index);
                    }
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
