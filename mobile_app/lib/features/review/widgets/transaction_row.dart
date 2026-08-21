import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../data/models/parsed_transaction.dart';

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
    final excluded = !transaction.include;
    final categoryName = transaction.effectiveCategoryName;

    return ListTile(
      onTap: onTap,
      onLongPress: onToggleInclude,
      leading: Checkbox(value: transaction.include, onChanged: (_) => onToggleInclude()),
      title: Text(
        transaction.payee,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: excluded ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatDisplayDate(transaction.date)),
          const SizedBox(width: 8),
          Flexible(
            child: Chip(
              label: Text(categoryName ?? 'Uncategorized', overflow: TextOverflow.ellipsis),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      trailing: Text(
        formatCents(transaction.amountCents),
        style: TextStyle(
          fontFeatures: const [FontFeature.tabularFigures()],
          decoration: excluded ? TextDecoration.lineThrough : null,
          color: excluded ? Theme.of(context).disabledColor : null,
        ),
      ),
    );
  }
}
