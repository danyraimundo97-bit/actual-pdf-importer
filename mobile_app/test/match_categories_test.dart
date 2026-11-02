import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/settings_store.dart';
import 'package:mobile_app/data/models/actual_category.dart';
import 'package:mobile_app/data/models/parsed_transaction.dart';
import 'package:mobile_app/features/categories/category_matching.dart';
import 'package:mobile_app/features/categories/match_categories.dart';

/// Records ensureActualCategory calls; fails on the name in [failOn].
class _FakeApi implements ImporterApi {
  _FakeApi({this.failOn});
  final String? failOn;
  final created = <({String group, String name, bool income})>[];

  @override
  Future<String> ensureActualCategory({
    required String budgetSyncId,
    required String groupName,
    required String name,
    bool isIncome = false,
  }) async {
    if (name == failOn) throw const ApiException(message: 'Could not reach the importer backend.');
    created.add((group: groupName, name: name, income: isIncome));
    return 'actual-${name.toLowerCase()}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const actual = [
  ActualCategoryGroup(
    id: 'ag1',
    name: 'Everyday',
    categories: [
      ActualCategory(id: 'a-groceries', name: 'GROCERIES'),
      ActualCategory(id: 'a-cafes', name: 'Restaurantes'),
      ActualCategory(id: 'a-fuel-1', name: 'Fuel'),
      ActualCategory(id: 'a-fuel-2', name: 'fuel'),
    ],
  ),
];

void main() {
  late AppDatabase db;
  late LocalCategoryStore store;
  late SettingsStore settings;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalCategoryStore(db);
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStore(await SharedPreferences.getInstance());
  });
  tearDown(() => db.close());

  final groceries = presetId('food.groceries');
  final restaurants = presetId('food.restaurants');
  final salary = presetId('income.salary');

  test('names match ignoring case, accents and spacing, like the backend', () {
    expect(categoryNameKey('  Restaurants &  Cafés '), categoryNameKey('restaurants & cafes'));
    expect(categoryNameKey('Restaurantes'), isNot(categoryNameKey('Restaurants & cafés')));
  });

  test('automatic matches need exactly one Actual category with the name', () async {
    final matches = autoMatchCategories(await store.allGroups(), actual);
    expect(matches[groceries], 'a-groceries');
    expect(matches.containsKey(presetId('transport.fuel')), isFalse, reason: 'two "fuel"s: ambiguous');
    expect(matches.containsKey(restaurants), isFalse);
  });

  test('the plan asks only about categories in use; an unused preset is never created', () async {
    await store.remember('CAFE', restaurants);
    await store.remember('EMPLOYER', salary);
    await store.remember('LIDL', groceries);
    final plan = planCategoryMatch(
      local: await store.allGroups(),
      actual: actual,
      links: const {},
      inUse: await store.categoriesInUse(),
      skipped: {salary},
    );
    expect(plan.automatic, {groceries: 'a-groceries'});
    expect(plan.rows.map((r) => r.category.id), [restaurants, salary]);
    expect(plan.rows.first.choice, isA<CreateInActual>());
    expect(plan.rows.last.choice, isA<SkipMatch>(), reason: 'skipped before');
  });

  test('applying links, creates in the right group, and remembers skips', () async {
    await store.remember('CAFE', restaurants);
    await store.remember('EMPLOYER', salary);
    await store.remember('PADARIA', presetId('food.groceries'));
    final api = _FakeApi();
    final base = planCategoryMatch(
      local: await store.allGroups(),
      actual: actual,
      links: const {},
      inUse: await store.categoriesInUse(),
      skipped: const {},
    );
    final plan = MatchPlan(
      automatic: base.automatic,
      alreadyLinked: 0,
      rows: [for (final r in base.rows) r.category.id == restaurants ? r.withChoice(const SkipMatch()) : r],
    );

    final result = await applyCategoryMatch(plan, budgetSyncId: 'b1', store: store, api: api, settings: settings);

    expect(result, (linked: 1, created: 1, skipped: 1));
    expect(api.created, [(group: 'Income', name: 'Salary', income: true)]);
    expect(await store.links('b1'), {groceries: 'a-groceries', salary: 'actual-salary'});
    expect(settings.skippedCategoryMatches('b1'), {restaurants});
    expect(
      pendingCategoryMatches(
        local: await store.allGroups(),
        links: await store.links('b1'),
        inUse: await store.categoriesInUse(budgetSyncId: 'b1'),
        skipped: settings.skippedCategoryMatches('b1'),
      ),
      0,
    );
  });

  test('a failure half-way keeps the links already made', () async {
    await store.remember('CAFE', restaurants);
    await store.remember('EMPLOYER', salary);
    final plan = planCategoryMatch(
      local: await store.allGroups(),
      actual: actual,
      links: const {},
      inUse: await store.categoriesInUse(),
      skipped: const {},
    );

    await expectLater(
      applyCategoryMatch(
        plan,
        budgetSyncId: 'b1',
        store: store,
        api: _FakeApi(failOn: 'Salary'),
        settings: settings,
      ),
      throwsA(isA<ApiException>()),
    );
    expect((await store.links('b1')).keys, containsAll([groceries, restaurants]));
    expect((await store.links('b1')).containsKey(salary), isFalse);
  });

  group('toActualCategories', () {
    ParsedTransaction tx(String? id) => ParsedTransaction(
      date: DateTime(2026, 7, 1),
      payee: 'X',
      amountCents: -1,
      rawLine: '',
      importedId: 'pdfimport-1',
      suggestedCategoryId: id,
      suggestedCategoryName: 'local name',
      suggestedFromHint: true,
    );

    test('a linked local suggestion becomes the Actual category, hint flag kept', () {
      final out = toActualCategories(
        tx(groceries),
        links: {groceries: 'a-groceries'},
        actualNames: {'a-groceries': 'GROCERIES'},
      );
      expect(out.suggestedCategoryId, 'a-groceries');
      expect(out.suggestedCategoryName, 'GROCERIES');
      expect(out.suggestedFromHint, isTrue);
    });

    test('an unlinked one, or one linked to a deleted Actual category, is dropped', () {
      expect(toActualCategories(tx(groceries), links: const {}, actualNames: const {}).suggestedCategoryId, isNull);
      expect(
        toActualCategories(tx(groceries), links: {groceries: 'gone'}, actualNames: const {}).suggestedCategoryId,
        isNull,
      );
    });

    test("an Actual id is left alone", () {
      expect(toActualCategories(tx('a-x'), links: const {}, actualNames: const {}).suggestedCategoryId, 'a-x');
    });
  });
}
