import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/category_emoji.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/category_suggestions.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';

const _log = AppLog('ledger');

/// What Home's "without a category" line counts. Tapping a row goes straight
/// to the category picker. The choice is for the payee: its other rows here take
/// it too and leave the list, and the memory has it for next time.
class UncategorizedScreen extends ConsumerWidget {
  const UncategorizedScreen({super.key});

  /// Sets the category on this row and on the payee's other rows in the list,
  /// and remembers the payee, so its next statement line gets it too.
  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    UncategorizedTransaction tx,
    List<UncategorizedTransaction> all,
  ) async {
    final store = ref.read(ledgerStoreProvider);
    final row = await store.transaction(tx.id);
    if (row == null) return;
    final scope = row.scope;
    final groups = scope == phoneScope
        ? await ref.read(localCategoryStoreProvider).groups(budgetSyncId: ref.read(appConfigProvider).budgetSyncId)
        : await ref.read(ledgerReportsProvider).categoryPicker(scope);
    if (!context.mounted) return;
    final choice = await pickCategory(context, groups);
    if (choice == null) return;

    final payee = tx.payee;
    final key = payee == null ? null : categoryMemoryKey(payee);
    final ids = [
      for (final other in all)
        if (other.id == tx.id ||
            (!other.inSplit && key != null && other.payee != null && categoryMemoryKey(other.payee!) == key))
          other.id,
    ];
    for (final id in ids) {
      await store.updateTransaction(id, categoryId: choice.id);
    }

    final memory = ref.read(localCategoryStoreProvider);
    final budget = scope == phoneScope ? null : scope;
    String? before;
    if (payee != null) {
      before = await memory.rememberedCategory(payee, budgetSyncId: budget);
      if (budget == null) {
        await memory.remember(payee, choice.id);
      } else {
        await memory.rememberActual(payee, budget, choice.id);
      }
      ref.read(categoryMemoryRevisionProvider.notifier).state++;
    }
    _log.info('Transactions categorized', {'count': ids.length});
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final name = splitCategoryName(choice.name).name;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          payee == null
              ? 'Moved to $name.'
              : ids.length == 1
              ? 'Moved to $name. $payee will go there next time.'
              : '${ids.length} from $payee moved to $name. Next time too.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final id in ids) {
              await store.updateTransaction(id, clearCategory: true);
            }
            if (payee == null) return;
            if (before == null) {
              await memory.forget(payee, budgetSyncId: budget);
            } else {
              await memory.remember(payee, before, budgetSyncId: budget);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(uncategorizedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Without a category')),
      body: rows.when(
        // A change reloads the list: keep the rows up meanwhile.
        skipLoadingOnReload: true,
        loading: () => const SkeletonRows(count: 6),
        error: (error, _) => ErrorRetry(
          title: 'Could not load these transactions',
          message: error is ApiException ? error.message : 'Something unexpected went wrong.',
          onRetry: () => ref.invalidate(uncategorizedProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.sell_outlined,
              title: 'All sorted',
              message: 'Every transaction from the last 30 days has a category.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                child: Text(
                  'The last 30 days, on your on-budget accounts. Tap one to choose a category for that payee.',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
              for (final tx in list) _Row(tx: tx, onTap: tx.inSplit ? null : () => _choose(context, ref, tx, list)),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final UncategorizedTransaction tx;
  final VoidCallback? onTap;

  const _Row({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final detail = '${dayLabel(tx.date)} · ${tx.account}';
    return Pressable(
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
                    tx.payee ?? 'No payee',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    tx.inSplit ? '$detail · part of a split, change it in Actual' : detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCents(tx.amountCents),
                  style: figures(context.text.bodyMedium)
                      .copyWith(fontWeight: FontWeight.w500, color: tx.amountCents > 0 ? context.tokens.inflow : null),
                ),
                if (onTap != null)
                  Text('Add category', style: context.text.bodySmall?.copyWith(color: context.colors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
