import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Label above, control in the middle, optional helper below. Fields never
/// rely on a placeholder or floating label to say what they are.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? helper;

  const LabeledField({super.key, required this.label, required this.child, this.helper});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelLarge),
        const SizedBox(height: Space.sm),
        child,
        if (helper != null) ...[
          const SizedBox(height: Space.xs + 2),
          Text(helper!, style: context.text.bodySmall),
        ],
      ],
    );
  }
}

/// A tappable control styled like a text input, for values chosen from a
/// picker (date, category, account) rather than typed.
class PickerField extends StatelessWidget {
  final String value;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData trailingIcon;

  /// Renders [value] muted, for "nothing chosen yet".
  final bool isPlaceholder;
  final bool useFigures;

  const PickerField({
    super.key,
    required this.value,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon = Icons.unfold_more_rounded,
    this.isPlaceholder = false,
    this.useFigures = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.bodyLarge?.copyWith(
      color: isPlaceholder ? colors.onSurfaceVariant : colors.onSurface,
    );
    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.controlAll,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: useFigures ? figures(style) : style,
                ),
              ),
              const SizedBox(width: Space.sm),
              Icon(trailingIcon, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
