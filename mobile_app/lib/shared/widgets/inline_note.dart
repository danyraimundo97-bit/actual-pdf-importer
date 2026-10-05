import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum NoteTone { neutral, success, error }

/// A short contextual message placed next to what it is about (a form
/// error, a connection result, a privacy notice). Toasts are only for
/// transient confirmations; anything the user may need to re-read goes here.
class InlineNote extends StatelessWidget {
  final String message;
  final NoteTone tone;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const InlineNote({
    super.key,
    required this.message,
    this.tone = NoteTone.neutral,
    this.icon,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color background, Color foreground, IconData defaultIcon) = switch (tone) {
      NoteTone.neutral => (colors.surfaceContainer, colors.onSurface, Icons.info_outline_rounded),
      NoteTone.success => (
        colors.surfaceContainer,
        colors.onSurface,
        Icons.check_circle_outline_rounded,
      ),
      NoteTone.error => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.error_outline_rounded,
      ),
    };
    final iconColor = switch (tone) {
      NoteTone.neutral => colors.onSurfaceVariant,
      NoteTone.success => context.tokens.inflow,
      NoteTone.error => colors.onErrorContainer,
    };

    return Semantics(
      liveRegion: tone == NoteTone.error,
      child: Container(
        width: double.infinity,
        padding: onDismiss == null
            ? const EdgeInsets.all(14)
            : const EdgeInsets.fromLTRB(14, 4, 4, 4),
        decoration: BoxDecoration(color: background, borderRadius: Radii.controlAll),
        child: Row(
          crossAxisAlignment: onDismiss == null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: onDismiss == null ? 1 : 0),
              child: Icon(icon ?? defaultIcon, size: 20, color: iconColor),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(message, style: context.text.bodyMedium?.copyWith(color: foreground)),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
