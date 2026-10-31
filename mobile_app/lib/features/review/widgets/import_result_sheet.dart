import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/collections.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/import_result.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/sheet_body.dart';

/// Shown after a successful import. Also offers to write back every
/// payee the user re-categorized during review, closing the learning loop
/// immediately instead of relying on a later "learn from Actual" pass.
class ImportResultSheet extends ConsumerStatefulWidget {
  final ImportResult result;
  final List<String> editedPayees;
  final List<ParsedTransaction> transactions;
  final String? budgetSyncId;

  const ImportResultSheet({
    super.key,
    required this.result,
    required this.editedPayees,
    required this.transactions,
    this.budgetSyncId,
  });

  @override
  ConsumerState<ImportResultSheet> createState() => _ImportResultSheetState();
}

class _ImportResultSheetState extends ConsumerState<ImportResultSheet> {
  bool _remembering = false;
  bool _remembered = false;

  Future<void> _rememberCategories() async {
    setState(() => _remembering = true);
    final api = ref.read(categoriesApiProvider);
    for (final payee in widget.editedPayees) {
      final tx = firstWhereOrNull(widget.transactions, (t) => t.payee == payee);
      final categoryId = tx?.effectiveCategoryId;
      if (tx == null || categoryId == null) continue;
      try {
        await api.upsert(
          payee: payee,
          categoryId: categoryId,
          categoryName: tx.effectiveCategoryName,
          budgetSyncId: widget.budgetSyncId,
        );
      } on ApiException {
        // Best-effort: the user can always fix it later in Category Memory.
      }
    }
    if (mounted) {
      setState(() {
        _remembering = false;
        _remembered = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final changed = widget.editedPayees.length;
    return SheetBody(
      title: 'Import complete',
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Stat(value: r.added, label: 'Added'),
            ),
            Expanded(
              child: _Stat(value: r.updated, label: 'Already in Actual'),
            ),
            Expanded(
              child: _Stat(value: r.categorized, label: 'Categorized'),
            ),
          ],
        ),
        if (changed > 0) ...[
          const SizedBox(height: Space.xl),
          const Divider(),
          const SizedBox(height: Space.xl),
          if (_remembered)
            const InlineNote(message: 'Saved to category memory.', tone: NoteTone.success)
          else ...[
            Text(
              'You changed the category for $changed payee${changed == 1 ? '' : 's'}. '
              'Remember ${changed == 1 ? 'it' : 'them'} for next time?',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: _remembering ? null : _rememberCategories,
              icon: _remembering
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sell_outlined, size: 18),
              label: const Text('Remember categories'),
            ),
          ],
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: figures(context.text.headlineMedium)),
        const SizedBox(height: 2),
        Text(label, style: context.text.bodySmall),
      ],
    );
  }
}
