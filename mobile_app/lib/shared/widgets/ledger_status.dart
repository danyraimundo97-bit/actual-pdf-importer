import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../data/ledger_sync_controller.dart';
import '../../data/providers.dart';

/// The quiet line on Home and Budget saying where the numbers come from
/// (docs/plans/local-ledger.md, Phases 4 and 5): "Kept on this phone"
/// without Actual; with it, how fresh the phone's copy of the budget is.
class LedgerStatus extends ConsumerWidget {
  /// The phone's own budget, not a copy of an Actual one.
  final bool onPhone;

  const LedgerStatus({super.key, required this.onPhone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final (IconData icon, String text, Color color) = onPhone
        ? (Icons.smartphone_rounded, 'Kept on this phone', colors.onSurfaceVariant)
        : _syncLine(ref.watch(ledgerSyncProvider), ref.watch(ledgerOutboxProvider).valueOrNull, colors);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: color)),
        ),
      ],
    );
  }

  static (IconData, String, Color) _syncLine(
    LedgerSyncStatus status,
    ({int waiting, int failed})? outbox,
    ColorScheme colors,
  ) {
    final muted = colors.onSurfaceVariant;
    final last = status.lastPulledAt;
    final waiting = outbox?.waiting ?? 0;
    final failed = outbox?.failed ?? 0;
    String changes(int n) => n == 1 ? '1 change' : '$n changes';
    if (status.running) return (Icons.sync_rounded, 'Syncing with Actual…', muted);
    if (failed > 0) return (Icons.error_outline_rounded, "${changes(failed)} couldn't be sent to Actual", colors.error);
    if (status.error != null) {
      return (
        Icons.cloud_off_rounded,
        waiting > 0
            ? "Couldn't reach Actual · ${changes(waiting)} waiting"
            : last == null
            ? "Couldn't reach Actual"
            : "Couldn't reach Actual · synced ${syncedAgo(last)}",
        colors.error,
      );
    }
    if (waiting > 0) return (Icons.cloud_upload_outlined, '${changes(waiting)} waiting', muted);
    if (last == null) return (Icons.cloud_outlined, 'A copy of your Actual budget', muted);
    return (Icons.cloud_done_outlined, 'Synced ${syncedAgo(last)}', muted);
  }
}

/// "just now", "5 min ago", "3 h ago", or the date.
String syncedAgo(DateTime at, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(at);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
  return 'on ${formatDisplayDate(at)}';
}
