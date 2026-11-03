import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/api/categories_api.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/category_sync.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/settings_store.dart';
import 'package:mobile_app/data/models/actual_category.dart';

/// A backend in memory, newest-wins like categorydb.ts's syncCategories,
/// so two phones can sync through it.
class _FakeBackend implements CategoriesApi {
  final mappings = <String, Map<String, Object?>>{}; // payee key → row
  final app = <String, Map<String, Object?>>{}; // kind|id → row
  final _syncedAt = <String, int>{};
  int _clock = 1000;
  final requests = <({String? budget, int? since, List<Map<String, Object?>> mappings})>[];

  @override
  Future<CategorySyncResponse> sync({
    String? budgetSyncId,
    int? since,
    required List<Map<String, Object?>> mappings,
    required List<Map<String, Object?>> appCategories,
  }) async {
    requests.add((budget: budgetSyncId, since: since, mappings: mappings));
    final now = ++_clock;
    final applied = <String>{}, lost = <String>{};
    for (final m in mappings) {
      final key = 'm|${(m['payee'] as String).trim().toLowerCase()}';
      final current = this.mappings[key];
      if (current != null && (current['updatedAt'] as int) >= (m['updatedAt'] as int)) {
        lost.add(key);
        continue;
      }
      this.mappings[key] = m;
      _syncedAt[key] = now;
      applied.add(key);
    }
    for (final c in appCategories) {
      final key = 'a|${c['kind']}|${c['id']}';
      final current = app[key];
      if (current != null && (current['updatedAt'] as int) >= (c['updatedAt'] as int)) {
        lost.add(key);
        continue;
      }
      app[key] = c;
      _syncedAt[key] = now;
      applied.add(key);
    }
    bool out(String key) => !applied.contains(key) && ((_syncedAt[key] ?? 0) >= (since ?? 0) || lost.contains(key));
    return (
      mappings: [
        if (budgetSyncId != null)
          for (final e in this.mappings.entries)
            if (out(e.key)) Map<String, dynamic>.from(e.value),
      ],
      appCategories: [
        for (final e in app.entries)
          if (out(e.key)) Map<String, dynamic>.from(e.value),
      ],
      now: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImporter implements ImporterApi {
  @override
  Future<List<ActualCategoryGroup>> getActualCategories({String? budgetSyncId}) async => const [
    ActualCategoryGroup(
      id: 'ag-food',
      name: 'Comida',
      categories: [
        ActualCategory(id: 'a-groceries', name: 'Supermercado'),
        ActualCategory(id: 'a-cafes', name: 'Cafés'),
      ],
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One phone: its database, store, settings and sync, with a clock.
class _Phone {
  _Phone(this.backend, this.settings) : db = AppDatabase(NativeDatabase.memory()) {
    store = LocalCategoryStore(db, now: () => DateTime.fromMillisecondsSinceEpoch(clock));
  }

  final _FakeBackend backend;
  final SettingsStore settings;
  final AppDatabase db;
  late final LocalCategoryStore store;
  int clock = 10000;

  Future<CategorySyncResult> sync({String? budget = 'b1', bool actual = true}) {
    clock += 10;
    return CategorySync(
      db,
      backend,
      _FakeImporter(),
      settings,
      now: () => DateTime.fromMillisecondsSinceEpoch(clock),
    ).run(budgetSyncId: budget, actualReady: actual);
  }
}

/// Fresh settings. SharedPreferences is one instance per test process, so a
/// second phone wipes it: it must not inherit the first phone's sync cursor.
Future<SettingsStore> _freshSettings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  return SettingsStore(prefs);
}

void main() {
  late _FakeBackend backend;
  late _Phone phone;

  setUp(() async {
    backend = _FakeBackend();
    phone = _Phone(backend, await _freshSettings());
  });
  tearDown(() => phone.db.close());

  test('mappings go up with the linked Actual id; unlinked ones wait', () async {
    await phone.store.remember('LIDL', presetId('food.groceries'));
    await phone.store.remember('CAFE', presetId('food.restaurants'));
    await phone.store.link(presetId('food.groceries'), 'b1', 'a-groceries');

    await phone.sync();
    expect(backend.mappings.keys, ['m|lidl']);
    expect(backend.mappings['m|lidl']!['categoryId'], 'a-groceries');
    expect(backend.mappings['m|lidl']!['categoryName'], 'Supermercado');

    // Linking later sends it, although the mapping itself is older.
    phone.clock += 10;
    await phone.store.link(presetId('food.restaurants'), 'b1', 'a-cafes');
    await phone.sync();
    expect(backend.mappings['m|cafe']!['categoryId'], 'a-cafes');
  });

  test('without Actual only the app categories travel', () async {
    await phone.store.remember('LIDL', presetId('food.groceries'));
    await phone.store.link(presetId('food.groceries'), 'b1', 'a-groceries');
    await phone.sync(actual: false);
    expect(backend.requests.single.budget, isNull);
    expect(backend.mappings, isEmpty);
    expect(backend.app.keys, contains('a|category|${presetId('food.groceries')}'));
  });

  test('a new phone gets back renames, user categories, links and the memory', () async {
    final pets = await phone.store.addGroup('Pets');
    final vet = await phone.store.addCategory(pets, 'Vet');
    await phone.store.renameCategory(presetId('food.groceries'), 'Supermarket');
    await phone.store.setCategoryHidden(presetId('travel.holidays'), true);
    await phone.store.link(vet, 'b1', 'a-cafes');
    await phone.store.remember('CLINICA VET', vet, budgetSyncId: 'b1');
    await phone.sync();

    final other = _Phone(backend, await _freshSettings());
    addTearDown(other.db.close);
    final result = await other.sync();
    expect(backend.requests.last.since, isNull, reason: 'a new phone asks for everything');

    expect(result.received, greaterThan(0));
    final names = {
      for (final g in await other.store.allGroups())
        for (final c in g.categories) c.id: (c.name, c.hidden),
    };
    expect(names[presetId('food.groceries')], ('Supermarket', false), reason: 'a rename beats a fresh seed');
    expect(names[presetId('travel.holidays')]!.$2, isTrue);
    expect(names[vet], ('Vet', false));
    expect(await other.store.links('b1'), {vet: 'a-cafes'});
    final s = await other.store.suggest('clinica vet', budgetSyncId: 'b1');
    expect(s?.categoryId, vet, reason: "the Actual id maps back to the phone's linked category");
  });

  test("a mapping to an Actual category the phone doesn't know gets a local copy", () async {
    backend.mappings['m|padaria'] = {
      'payee': 'PADARIA',
      'categoryId': 'a-groceries',
      'categoryName': 'Supermercado',
      'updatedAt': 500,
      'deleted': false,
    };

    await phone.sync();

    final s = await phone.store.suggest('PADARIA', budgetSyncId: 'b1');
    expect(s?.categoryId, 'actual:a-groceries');
    expect(s?.categoryName, 'Supermercado');
    expect(await phone.store.links('b1'), containsPair('actual:a-groceries', 'a-groceries'));

    final picker = await phone.store.groups(budgetSyncId: 'b1');
    expect(picker.any((g) => g.name == 'Comida'), isTrue, reason: 'shown for its budget');
    final otherBudget = await phone.store.groups(budgetSyncId: 'b2');
    expect(otherBudget.any((g) => g.name == 'Comida'), isFalse);
    expect((await phone.store.allGroups()).any((g) => g.name == 'Comida'), isFalse, reason: "Actual's to edit");
  });

  test('newest wins both ways, and forgetting travels', () async {
    await phone.store.link(presetId('food.groceries'), 'b1', 'a-groceries');
    await phone.store.link(presetId('food.restaurants'), 'b1', 'a-cafes');
    await phone.store.remember('LIDL', presetId('food.groceries'), budgetSyncId: 'b1');
    await phone.sync();

    // The backend changes it later (another phone, or an import).
    backend.mappings['m|lidl'] = {...backend.mappings['m|lidl']!, 'categoryId': 'a-cafes', 'updatedAt': 99999};
    backend._syncedAt['m|lidl'] = backend._clock + 1;
    await phone.sync();
    expect((await phone.store.suggest('LIDL', budgetSyncId: 'b1'))?.categoryId, presetId('food.restaurants'));

    // Forgotten on the phone, later still: the backend hears of it.
    phone.clock = 200000;
    await phone.store.forget('LIDL', budgetSyncId: 'b1');
    await phone.sync();
    expect(backend.mappings['m|lidl']!['deleted'], isTrue);
  });

  test('a second sync sends only what changed since the first', () async {
    await phone.store.link(presetId('food.groceries'), 'b1', 'a-groceries');
    await phone.store.remember('LIDL', presetId('food.groceries'), budgetSyncId: 'b1');
    final first = await phone.sync();
    expect(first.sent, greaterThan(1));

    final second = await phone.sync();
    expect(second.sent, 0);
    expect(backend.requests.last.since, isNotNull);

    phone.clock += 10;
    await phone.store.remember('ALDI', presetId('food.groceries'), budgetSyncId: 'b1');
    final third = await phone.sync();
    expect(third.sent, 1);
    expect(backend.requests.last.mappings.single['payee'], 'ALDI');
  });

  test('presets seeded on a fresh phone are older than any edit', () async {
    final rows = await (phone.db.select(phone.db.categories)..where((c) => c.source.equals('preset'))).get();
    expect(rows, isNotEmpty);
    expect(rows.every((c) => c.updatedAt == 0), isTrue);
  });
}
