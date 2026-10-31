import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Composed empty/error state: what happened, and the one thing to do next.
/// Left-aligned and placed in the upper part of the space, so it reads as
/// content rather than a dialog floating in the middle of the screen.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool isError;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isError ? colors.errorContainer : colors.surfaceContainer,
              borderRadius: Radii.controlAll,
            ),
            child: Icon(
              icon,
              size: 24,
              color: isError ? colors.onErrorContainer : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: Space.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: actionIcon == null ? null : Icon(actionIcon, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
