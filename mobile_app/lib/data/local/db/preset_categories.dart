/// The predefined categories (docs/plans/dart-parser.md, Phase 4; the list
/// was reviewed 2026-11-02). Names are English, like the rest of the UI.
///
/// `key` is stable forever: it's how a later app version recognises a
/// preset the database already has (possibly renamed or hidden by the
/// user). Add new presets with new keys; never reuse or rename a key.
library;

class PresetCategory {
  final String key;
  final String name;

  /// Shown until the user picks another. Old enough to exist on the oldest
  /// phones the app runs on (Android 6, Emoji 2).
  final String emoji;
  const PresetCategory(this.key, this.name, this.emoji);
}

class PresetGroup {
  final String key;
  final String name;
  final bool isIncome;
  final List<PresetCategory> categories;
  const PresetGroup(this.key, this.name, this.categories, {this.isIncome = false});
}

/// A preset's local id. Prefixed rather than random so seeding is
/// idempotent; it can't clash with Actual's ids (plain UUIDs).
String presetId(String key) => 'preset:$key';

const presetGroups = <PresetGroup>[
  PresetGroup('home', 'Home', [
    PresetCategory('home.rent', 'Rent / mortgage', '🏠'),
    PresetCategory('home.utilities', 'Utilities', '💡'),
    PresetCategory('home.internet', 'Internet & phone', '📶'),
    PresetCategory('home.furniture', 'Home & furniture', '🛋️'),
  ]),
  PresetGroup('food', 'Food', [
    PresetCategory('food.groceries', 'Groceries', '🛒'),
    PresetCategory('food.restaurants', 'Restaurants & cafés', '🍽️'),
  ]),
  PresetGroup('transport', 'Transport', [
    PresetCategory('transport.fuel', 'Fuel', '⛽'),
    PresetCategory('transport.public', 'Public transport', '🚆'),
    PresetCategory('transport.car', 'Car', '🚗'),
    PresetCategory('transport.taxi', 'Taxi & ride-hailing', '🚕'),
  ]),
  PresetGroup('health', 'Health', [
    PresetCategory('health.pharmacy', 'Health & pharmacy', '💊'),
    PresetCategory('health.insurance', 'Insurance', '🛡️'),
  ]),
  PresetGroup('personal', 'Personal', [
    PresetCategory('personal.shopping', 'Shopping & clothing', '🛍️'),
    PresetCategory('personal.subscriptions', 'Subscriptions', '📺'),
    PresetCategory('personal.entertainment', 'Entertainment', '🎬'),
    PresetCategory('personal.sports', 'Sports & fitness', '🏃'),
    PresetCategory('personal.education', 'Education', '🎓'),
    PresetCategory('personal.gifts', 'Gifts & donations', '🎁'),
    PresetCategory('personal.care', 'Personal care', '💅'),
  ]),
  PresetGroup('travel', 'Travel', [PresetCategory('travel.holidays', 'Travel & holidays', '✈️')]),
  PresetGroup('money', 'Money', [
    PresetCategory('money.fees', 'Bank fees', '🏦'),
    PresetCategory('money.taxes', 'Taxes', '🏛️'),
    PresetCategory('money.savings', 'Savings & investments', '💰'),
    PresetCategory('money.transfers', 'Transfers', '💸'),
    // Doesn't count towards income, spending or the budget (LedgerReports).
    PresetCategory('money.between_accounts', 'Between my accounts', '🔁'),
    // Doesn't count anywhere: not in the totals, balances or net worth.
    PresetCategory('money.not_counted', 'Not counted', '🚫'),
  ]),
  PresetGroup('income', 'Income', [
    PresetCategory('income.salary', 'Salary', '💼'),
    PresetCategory('income.refunds', 'Refunds', '↩️'),
    PresetCategory('income.other', 'Other income', '💵'),
  ], isIncome: true),
];
