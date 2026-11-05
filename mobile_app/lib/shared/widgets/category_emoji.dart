import 'package:flutter/material.dart';

import '../../core/format/category_emoji.dart';
import '../../core/theme/app_theme.dart';

/// "🛒 Groceries", for a line of text.
String withEmoji(String? emoji, String text) => emoji == null ? text : '$emoji $text';

/// The column a category's emoji sits in, as wide as the chevron of the group
/// above it, so names line up with the group's name. A category without one
/// shows its first letter, which keeps the column and reads as a choice not
/// made. Decorative for screen readers: the row already says the name.
class CategoryGlyph extends StatelessWidget {
  final String? emoji;

  /// Null leaves the column empty ("Uncategorized", "Other").
  final String? name;

  /// For a quiet row: a colour emoji can't take the row's muted text colour.
  final bool muted;

  const CategoryGlyph({super.key, required this.emoji, this.name, this.muted = false});

  /// The chevron's 20 and the 4 after it.
  static const width = 20.0;
  static const gap = Space.xs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final letter = name == null || name!.trim().isEmpty ? '' : name!.trim().characters.first.toUpperCase();
    final child = emoji != null
        ? Text(emoji!, style: const TextStyle(fontSize: 15, height: 1.2))
        : Text(
            letter,
            style: context.text.bodySmall?.copyWith(
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: MediaQuery.withClampedTextScaling(
          // Stays inside the column at 2x text.
          maxScaleFactor: 1.2,
          child: Center(
            child: Opacity(opacity: muted && emoji != null ? 0.55 : 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// Chooses an emoji. Returns the emoji, '' for none, or null when dismissed.
Future<String?> pickEmoji(BuildContext context, {required String categoryName, String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EmojiSheet(categoryName: categoryName, current: current),
  );
}

class _EmojiSheet extends StatefulWidget {
  final String categoryName;
  final String? current;

  const _EmojiSheet({required this.categoryName, this.current});

  @override
  State<_EmojiSheet> createState() => _EmojiSheetState();
}

class _EmojiSheetState extends State<_EmojiSheet> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typed = _typed.text.trim();
    final valid = isSingleEmoji(typed);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.categoryName, style: context.text.titleLarge)),
              if (widget.current != null)
                TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('No emoji')),
            ],
          ),
          const SizedBox(height: Space.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 48),
            itemCount: emojiChoices.length,
            itemBuilder: (context, i) {
              final emoji = emojiChoices[i];
              final selected = emoji == widget.current;
              return Material(
                color: selected ? colors.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.control),
                  onTap: () => Navigator.pop(context, emoji),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24, height: 1.2))),
                ),
              );
            },
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _typed,
            decoration: InputDecoration(
              hintText: 'Or type your own',
              errorText: typed.isNotEmpty && !valid ? 'One emoji, please' : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (valid) Navigator.pop(context, typed);
            },
          ),
          if (valid) ...[
            const SizedBox(height: Space.md),
            FilledButton(onPressed: () => Navigator.pop(context, typed), child: Text('Use $typed')),
          ],
        ],
      ),
    );
  }
}
