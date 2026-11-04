import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The quiet line on Home and Budget saying where the numbers come from
/// while Actual isn't connected (docs/plans/local-ledger.md, Phase 4). The
/// sync (Phase 5) adds "Synced 2 min ago" and "3 changes waiting to sync".
class OnPhoneStatus extends StatelessWidget {
  const OnPhoneStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.smartphone_rounded, size: 16, color: muted),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text('Kept on this phone', style: context.text.bodySmall?.copyWith(color: muted)),
        ),
      ],
    );
  }
}
