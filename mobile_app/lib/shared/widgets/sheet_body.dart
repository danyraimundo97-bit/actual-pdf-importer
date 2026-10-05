import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Common layout for the app's bottom sheets: title, optional one-line
/// description, content, then actions pinned below. Lifts above the
/// keyboard and scrolls when the content does not fit.
class SheetBody extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  /// Usually a Cancel + primary pair; laid out as equal-width buttons.
  final List<Widget> actions;

  const SheetBody({
    super.key,
    required this.title,
    this.description,
    required this.children,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: context.text.titleLarge),
              if (description != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  description!,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: Space.xl),
              ...children,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: Space.md),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
