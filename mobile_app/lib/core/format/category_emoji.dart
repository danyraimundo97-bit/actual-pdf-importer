import '../../data/local/db/preset_categories.dart';

// A category's emoji. The phone's categories keep theirs in the database (a
// preset has one by its key until the user changes it). Actual has no field
// for it, and people there start the name with one, so that's where an
// Actual category's comes from.

/// One emoji: a flag, or a pictograph with its variation, skin tone and
/// joined parts.
const _oneEmoji =
    r'(?:\p{Regional_Indicator}\p{Regional_Indicator}'
    r'|\p{Extended_Pictographic}[\u{FE0F}\p{Emoji_Modifier}]?'
    r'(?:\u{200D}\p{Extended_Pictographic}[\u{FE0F}\p{Emoji_Modifier}]?)*)';

final _leading = RegExp('^\\s*($_oneEmoji)[\\s\\-–—:·]*', unicode: true);
final _only = RegExp('^$_oneEmoji\$', unicode: true);

/// True when [text] is exactly one emoji.
bool isSingleEmoji(String text) => _only.hasMatch(text.trim());

/// "🛒 Groceries" as an emoji and a name. A name that is nothing but an emoji
/// stays a name, since the row would otherwise have no words.
({String? emoji, String name}) splitCategoryName(String name) {
  final match = _leading.firstMatch(name);
  if (match == null || match.end == name.length) return (emoji: null, name: name);
  return (emoji: match.group(1), name: name.substring(match.end));
}

final Map<String, String> _presetEmojis = {
  for (final g in presetGroups)
    for (final c in g.categories) c.key: c.emoji,
};

/// What a phone category shows. [stored]: null is "not chosen", which for a
/// preset is its own emoji; '' is "none", chosen by the user.
String? phoneCategoryEmoji(String? stored, String? presetKey) {
  if (stored != null) return stored.isEmpty ? null : stored;
  return _presetEmojis[presetKey];
}

/// The choices in the emoji sheet, in rough order of how budgets use them.
const emojiChoices = <String>[
  '🏠', '💡', '📶', '🛋️', '🔧', '🧹', '🌱', '🐾', //
  '🛒', '🍽️', '☕', '🍕', '🍺', '🥖', '🍎', '🍷', //
  '⛽', '🚆', '🚗', '🚕', '🚲', '🅿️', '✈️', '🏖️', //
  '💊', '🛡️', '🩺', '🦷', '👓', '💅', '🏃', '🏋️', //
  '🛍️', '👕', '👟', '📱', '💻', '📺', '🎬', '🎮', //
  '🎵', '📚', '🎓', '👶', '🎁', '❤️', '🎉', '🎨', //
  '🏦', '🏛️', '💰', '💸', '💼', '💵', '↩️', '📈', //
];
