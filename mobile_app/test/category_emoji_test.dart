import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/core/format/category_emoji.dart';
import 'package:mobile_app/data/local/db/app_category_rows.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/ledger_reports.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  group('splitCategoryName', () {
    test('takes a leading emoji off the name', () {
      expect(splitCategoryName('🛒 Groceries'), (emoji: '🛒', name: 'Groceries'));
      expect(splitCategoryName('🛒Groceries'), (emoji: '🛒', name: 'Groceries'));
      expect(splitCategoryName('🛒 - Groceries'), (emoji: '🛒', name: 'Groceries'));
    });

    test('keeps variations, skin tones, joined emoji and flags whole', () {
      expect(splitCategoryName('🛋️ Home').emoji, '🛋️');
      expect(splitCategoryName('👍🏽 Good').emoji, '👍🏽');
      expect(splitCategoryName('👨‍👩‍👧 Family').emoji, '👨‍👩‍👧');
      expect(splitCategoryName('🇵🇹 Portugal').emoji, '🇵🇹');
    });

    test('leaves other names alone', () {
      expect(splitCategoryName('Groceries'), (emoji: null, name: 'Groceries'));
      expect(splitCategoryName('Food 🛒'), (emoji: null, name: 'Food 🛒'));
      expect(splitCategoryName('2 cars'), (emoji: null, name: '2 cars'));
      expect(splitCategoryName('🛒'), (emoji: null, name: '🛒'));
    });
  });

  test('isSingleEmoji', () {
    expect(isSingleEmoji('🛒'), isTrue);
    expect(isSingleEmoji(' 🛋️ '), isTrue);
    expect(isSingleEmoji('🛒🛒'), isFalse);
    expect(isSingleEmoji('a'), isFalse);
    expect(isSingleEmoji(''), isFalse);
  });

  test('every choice and preset is one emoji', () {
    for (final emoji in emojiChoices) {
      expect(isSingleEmoji(emoji), isTrue, reason: emoji);
    }
    for (final g in presetGroups) {
      for (final c in g.categories) {
        expect(isSingleEmoji(c.emoji), isTrue, reason: c.key);
      }
    }
  });

  group('with a database', () {
    late AppDatabase db;
    late LocalCategoryStore categories;
    late LedgerReports reports;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      categories = LocalCategoryStore(db);
      reports = LedgerReports(db, LedgerStore(db));
    });
    tearDown(() => db.close());

    Future<void> actualCategory(String id, String name) => db
        .into(db.ledgerCategories)
        .insert(
          LedgerCategoriesCompanion.insert(
            scope: 'budget',
            id: id,
            groupId: 'g',
            groupName: 'Everyday',
            name: name,
            sort: 0,
            groupSort: 0,
          ),
        );

    Future<Map<String, ({String name, String? emoji})>> picker(String scope) async => {
      for (final g in await reports.categoryPicker(scope))
        for (final c in g.categories) c.id: (name: c.name, emoji: c.emoji),
    };

    test("a preset shows its own until changed, and none stays none", () async {
      expect((await picker(phoneScope))[presetId('food.groceries')]?.emoji, '🛒');

      await categories.setCategoryEmoji(presetId('food.groceries'), '🥖');
      expect((await picker(phoneScope))[presetId('food.groceries')]?.emoji, '🥖');

      await categories.setCategoryEmoji(presetId('food.groceries'), '');
      expect((await picker(phoneScope))[presetId('food.groceries')]?.emoji, isNull);
    });

    test('a chosen emoji travels with the sync and backups', () async {
      await categories.setCategoryEmoji(presetId('food.groceries'), '🥖');
      final rows = await appCategoryRows(db);
      final row = rows.firstWhere((r) => r['id'] == presetId('food.groceries'));
      expect((row['data'] as Map)['emoji'], '🥖');
    });

    test('an Actual category: its name first, then a link, then the same name', () async {
      await actualCategory('a1', '🍕 Eating out');
      await actualCategory('a2', 'Supermercado');
      await actualCategory('a3', 'groceries');
      await actualCategory('a4', 'Something else');
      await categories.link(presetId('food.restaurants'), 'budget', 'a2');

      final actual = await picker('budget');
      expect(actual['a1'], (name: 'Eating out', emoji: '🍕'));
      expect(actual['a2'], (name: 'Supermercado', emoji: '🍽️'));
      expect(actual['a3'], (name: 'groceries', emoji: '🛒'));
      expect(actual['a4'], (name: 'Something else', emoji: null));
    });

    test('a row from an older app without the field reads as not chosen', () async {
      await (db.update(db.categories)..where((c) => c.id.equals(presetId('food.groceries'))))
          .write(const CategoriesCompanion(emoji: Value(null)));
      expect((await picker(phoneScope))[presetId('food.groceries')]?.emoji, '🛒');
    });
  });
}
