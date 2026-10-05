import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/parsed_transaction.dart';

/// One parsed line. The date lives in the group header above it (see
/// ReviewScreen), so the row spends its width on payee, category and amount.
class TransactionRow extends StatelessWidget {
  final ParsedTransaction transaction;
  final VoidCallback onTap;
  final VoidCallback onToggleInclude;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onToggleInclude,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final excluded = !transaction.include;
    final categoryName = transaction.effectiveCategoryName;
    final isInflow = transaction.amountCents > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onToggleInclude,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.gutter, Space.sm),
        child: Row(
          children: [
            Checkbox(
              value: transaction.include,
              onChanged: (_) => onToggleInclude(),
              semanticLabel: 'Include ${transaction.payee}',
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: AnimatedOpacity(
                opacity: excluded ? 0.45 : 1,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.payee,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: excluded ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _CategoryLine(name: categoryName, edited: transaction.edited),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Text(
                      formatCents(transaction.amountCents),
                      style: figures(context.text.bodyLarge).copyWith(
                        fontWeight: FontWeight.w500,
                        color: isInflow ? context.tokens.inflow : colors.onSurface,
                        decoration: excluded ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  final String? name;
  final bool edited;

  const _CategoryLine({required this.name, required this.edited});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uncategorized = name == null;
    final color = uncategorized ? colors.primary : colors.onSurfaceVariant;
    return Row(
      children: [
        Icon(uncategorized ? Icons.add_rounded : Icons.sell_outlined, size: 14, color: color),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            name ?? 'Add category',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: color,
              fontWeight: uncategorized ? FontWeight.w600 : null,
            ),
          ),
        ),
        if (edited) ...[
          const SizedBox(width: Space.sm),
          Icon(Icons.edit_outlined, size: 13, color: colors.onSurfaceVariant),
          const SizedBox(width: 2),
          Text('Edited', style: context.text.bodySmall),
        ],
      ],
    );
  }
}
