import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/collections.dart';
import '../../../core/errors/api_exception.dart';
import '../../../data/models/import_result.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../data/providers.dart';

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
        // Best-effort — the user can always fix it later in Category Memory.
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Import complete', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('${r.added} added · ${r.updated} updated · ${r.categorized} categorized'),
          const SizedBox(height: 8),
          Text(
            '"Updated" means those transactions already existed in Actual and were matched, '
            'not duplicated.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.editedPayees.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              'Remember ${widget.editedPayees.length} '
              'categor${widget.editedPayees.length == 1 ? 'y' : 'ies'} you changed?',
            ),
            const SizedBox(height: 8),
            if (_remembered)
              const Text('Saved to category memory.')
            else
              FilledButton(
                onPressed: _remembering ? null : _rememberCategories,
                child: _remembering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Remember these categories'),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ],
          ),
        ],
      ),
    );
  }
}
