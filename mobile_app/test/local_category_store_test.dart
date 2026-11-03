import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/db/preset_hints.dart';

void main() {
  late AppDatabase db;
  late LocalCategoryStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalCategoryStore(db);
  });
  tearDown(() => db.close());

  group('presets', () {
    test('every preset is seeded, income last', () async {
      final groups = await store.groups();
      expect(groups.map((g) => g.name), presetGroups.map((g) => g.name));
      expect(groups.last.name, 'Income');
      final count = groups.fold<int>(0, (n, g) => n + g.categories.length);
      expect(count, presetGroups.fold<int>(0, (n, g) => n + g.categories.length));
      expect(groups.first.categories.first.id, presetId('home.rent'));
    });

    test('re-seeding keeps renames and hidden presets, and adds missing ones', () async {
      await store.groups(); // opens and seeds
      final groceries = presetId('food.groceries');
      await (db.update(
        db.categories,
      )..where((c) => c.id.equals(groceries))).write(const CategoriesCompanion(name: Value('Supermarket')));
      await (db.update(
        db.categories,
      )..where((c) => c.id.equals(presetId('travel.holidays')))).write(const CategoriesCompanion(hidden: Value(true)));
      // As if an older app version never had this preset.
      await (db.delete(db.categories)..where((c) => c.id.equals(presetId('money.taxes')))).go();

      await db.seedPresets();

      final names = {
        for (final g in await store.groups())
          for (final c in g.categories) c.id: c.name,
      };
      expect(names[groceries], 'Supermarket');
      expect(names.containsKey(presetId('travel.holidays')), isFalse, reason: 'still hidden');
      expect(names[presetId('money.taxes')], 'Taxes');
      expect((await store.groups()).any((g) => g.name == 'Travel'), isFalse, reason: 'empty group left out');
    });
  });

  group('memory', () {
    const groceries = 'preset:food.groceries';
    const restaurants = 'preset:food.restaurants';

    test('normalised like the backend: case and spacing do not matter', () async {
      await store.remember('Padaria  Central ', restaurants);
      final s = await store.suggest('PADARIA CENTRAL');
      expect(s?.categoryId, restaurants);
      expect(s?.categoryName, 'Restaurants & cafés');
      expect(s?.source, SuggestionSource.memory);
    });

    test("the budget's mapping first, then the unscoped one", () async {
      await store.remember('SHOP', groceries);
      await store.remember('SHOP', restaurants, budgetSyncId: 'b1');
      expect((await store.suggest('shop', budgetSyncId: 'b1'))?.categoryId, restaurants);
      expect((await store.suggest('shop', budgetSyncId: 'b2'))?.categoryId, groceries);
      expect((await store.suggest('shop'))?.categoryId, groceries);
    });

    test('the memory beats a hint, and forgetting falls back to the hint', () async {
      await store.remember('CONTINENTE MATOSINHOS', restaurants);
      expect((await store.suggest('CONTINENTE MATOSINHOS'))?.source, SuggestionSource.memory);

      await store.forget('continente matosinhos');
      final s = await store.suggest('CONTINENTE MATOSINHOS');
      expect(s?.source, SuggestionSource.hint);
      expect(s?.categoryId, groceries);
      expect(await store.mappings(), isEmpty);
      expect(await db.select(db.payeeCategories).get(), hasLength(1), reason: 'tombstone kept for the sync');
    });

    test('remembering again re-points the mapping', () async {
      await store.remember('SHOP', groceries);
      await store.remember('shop', restaurants);
      final all = await store.mappings();
      expect(all.single.categoryId, restaurants);
    });
  });

  group('hints', () {
    test('match whole merchant names, any case or accents', () {
      expect(hintPresetKey('Compra Pingo Doce Lisboa'), 'food.groceries');
      expect(hintPresetKey('FARMÁCIA CENTRAL'), 'health.pharmacy');
      expect(hintPresetKey('GALP ENERGIA SA'), 'home.utilities');
      expect(hintPresetKey('GALP AREEIRO'), 'transport.fuel');
      expect(hintPresetKey('UBER   *TRIP'), 'transport.taxi');
    });

    test('a name inside another word is not a match', () {
      expect(hintPresetKey('TRF BPI'), isNull);
      expect(hintPresetKey('NOSSA LOJA'), isNull);
    });

    test('a hidden preset is not suggested', () async {
      await (db.update(
        db.categories,
      )..where((c) => c.id.equals(presetId('food.groceries')))).write(const CategoriesCompanion(hidden: Value(true)));
      expect(await store.suggest('LIDL'), isNull);
    });
  });

  group('managing categories', () {
    test('a user category gets a local id, sorts last and can be picked and remembered', () async {
      final id = await store.addCategory(presetId('food'), '  Bakery   goods ');
      expect(id, startsWith('local:'));
      expect(LocalCategoryStore.isLocalId(id), isTrue);

      final food = (await store.groups()).firstWhere((g) => g.name == 'Food');
      expect(food.categories.last.name, 'Bakery goods');

      await store.remember('PADARIA', id);
      expect((await store.suggest('padaria'))?.categoryName, 'Bakery goods');
    });

    test('a user group goes after the other expense groups, before income', () async {
      await store.addGroup('Pets');
      final names = (await store.groups()).map((g) => g.name).toList();
      expect(names, isNot(contains('Pets')), reason: 'empty groups stay out of the picker');
      final all = (await store.allGroups()).map((g) => g.name).toList();
      expect(all.indexOf('Pets'), all.indexOf('Income') - 1);
    });

    test('renaming changes the name everywhere, mappings included', () async {
      await store.remember('LIDL', presetId('food.groceries'));
      await store.renameCategory(presetId('food.groceries'), 'Supermarket');
      expect((await store.suggest('LIDL'))?.categoryName, 'Supermarket');
      expect((await store.mappings()).single.categoryName, 'Supermarket');
    });

    test('an empty name is refused', () async {
      expect(() => store.renameCategory(presetId('food.groceries'), '   '), throwsArgumentError);
    });

    test('hiding stops suggestions but keeps the mapping; showing brings it back', () async {
      final restaurants = presetId('food.restaurants');
      await store.remember('CAFE CENTRAL', restaurants);
      await store.setCategoryHidden(restaurants, true);
      expect(await store.suggest('CAFE CENTRAL'), isNull);
      expect(await store.mappings(), hasLength(1));

      await store.setCategoryHidden(restaurants, false);
      expect((await store.suggest('CAFE CENTRAL'))?.categoryId, restaurants);
    });

    test('restoring brings back hidden presets only', () async {
      final user = await store.addCategory(presetId('food'), 'Bakery');
      await store.setCategoryHidden(user, true);
      await store.setCategoryHidden(presetId('food.groceries'), true);
      await store.renameCategory(presetId('food.restaurants'), 'Eating out');

      expect(await store.restoreHiddenPresets(), 1);
      final food = (await store.allGroups()).firstWhere((g) => g.name == 'Food');
      final byId = {for (final c in food.categories) c.id: c};
      expect(byId[presetId('food.groceries')]!.hidden, isFalse);
      expect(byId[user]!.hidden, isTrue, reason: "the user's own choice stays");
      expect(byId[presetId('food.restaurants')]!.name, 'Eating out');
    });

    test('forget all leaves tombstones for one scope only', () async {
      await store.remember('A', presetId('food.groceries'));
      await store.remember('B', presetId('food.groceries'));
      await store.remember('C', presetId('food.groceries'), budgetSyncId: 'b1');
      expect(await store.clear(), 2);
      expect(await store.mappings(), isEmpty);
      expect(await store.mappings(budgetSyncId: 'b1'), hasLength(1));
    });
  });

  test('a version 1 database (before sync) upgrades and keeps its links', () async {
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE category_groups (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, sort INTEGER NOT NULL,
              is_income INTEGER NOT NULL DEFAULT 0, source TEXT NOT NULL, preset_key TEXT NULL UNIQUE,
              hidden INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);
            CREATE TABLE categories (id TEXT NOT NULL PRIMARY KEY, group_id TEXT NOT NULL REFERENCES category_groups (id),
              name TEXT NOT NULL, sort INTEGER NOT NULL, source TEXT NOT NULL, preset_key TEXT NULL UNIQUE,
              hidden INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);
            CREATE TABLE category_links (category_id TEXT NOT NULL REFERENCES categories (id),
              budget_sync_id TEXT NOT NULL, actual_category_id TEXT NOT NULL,
              PRIMARY KEY (category_id, budget_sync_id));
            CREATE TABLE payee_categories (budget_sync_id TEXT NOT NULL, payee_key TEXT NOT NULL,
              payee_label TEXT NOT NULL, category_id TEXT NOT NULL REFERENCES categories (id),
              updated_at INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (budget_sync_id, payee_key));
            INSERT INTO category_groups VALUES ('preset:food', 'Food', 1, 0, 'preset', 'food', 0, 5);
            INSERT INTO categories VALUES ('preset:food.groceries', 'preset:food', 'Groceries', 0, 'preset', 'food.groceries', 0, 5);
            INSERT INTO category_links VALUES ('preset:food.groceries', 'b1', 'a-groceries');
          ''');
          raw.userVersion = 1;
        },
      ),
    );
    addTearDown(old.close);

    expect(await LocalCategoryStore(old).links('b1'), {presetId('food.groceries'): 'a-groceries'});
    final link = await old.select(old.categoryLinks).getSingle();
    expect(link.updatedAt, 0);
  });
}
