import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/account_page.dart';
import '../../../shared/widgets/category_emoji.dart';

/// Rows of a transaction list, newest first, with a header per day. [onTap]
/// gives each row its action, if it has one.
List<Widget> transactionRowsWithDayHeaders(
  List<AccountTransaction> rows, {
  VoidCallback? Function(AccountTransaction)? onTap,
}) {
  final out = <Widget>[];
  DateTime? day;
  for (final tx in rows) {
    if (day == null || !DateUtils.isSameDay(day, tx.date)) {
      day = tx.date;
      out.add(DayHeader(date: tx.date));
    }
    out.add(TransactionRow(tx: tx, onTap: onTap?.call(tx)));
  }
  return out;
}

class DayHeader extends StatelessWidget {
  final DateTime date;

  const DayHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final label = dayLabel(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
      child: Text(label, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
    );
  }
}

class TransactionRow extends StatelessWidget {
  final AccountTransaction tx;
  final VoidCallback? onTap;

  const TransactionRow({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String detail;
    if (tx.openingBalance) {
      detail = 'Changed in Settings › Accounts';
    } else if (tx.transfer) {
      detail = 'Transfer';
    } else if (tx.splits.isNotEmpty) {
      detail = 'Split: ${tx.splits.map((s) => s.category ?? 'Uncategorized').toSet().join(', ')}';
    } else {
      detail = withEmoji(tx.categoryEmoji, tx.category ?? 'Uncategorized');
    }
    final account = tx.accountName;
    final uncategorized = !tx.openingBalance && !tx.transfer && tx.splits.isEmpty && tx.category == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm + 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // A balance adjustment has no payee; its note says what it is.
                    tx.payee ?? (tx.openingBalance ? 'Opening balance' : tx.notes ?? 'No payee'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    account == null ? detail : '$account · $detail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: uncategorized ? colors.primary : null),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Text(
              formatCents(tx.amountCents),
              style: figures(context.text.bodyLarge)
                  .copyWith(fontWeight: FontWeight.w500, color: tx.amountCents > 0 ? context.tokens.inflow : null),
            ),
          ],
        ),
      ),
    );
  }
}
