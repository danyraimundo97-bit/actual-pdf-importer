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
}
