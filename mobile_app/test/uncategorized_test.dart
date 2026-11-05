import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/ledger_builders.dart';
import 'package:mobile_app/data/local/ledger_reports.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:mobile_app/features/dashboard/screens/uncategorized_screen.dart';

// Home's "without a category" opens the transactions it counts, not the
// category memory.

void main() {
  late AppDatabase db;
  late LedgerStore store;
  final now = DateTime.now();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LedgerStore(db);
  });
  tearDown(() => db.close());

  Future<String> account({bool offBudget = false}) =>
      store.createAccount(phoneScope, name: offBudget ? 'Savings' : 'Checking', offBudget: offBudget);
  LedgerDraft draft(int cents, {String? payee, int daysAgo = 1, String? categoryId}) => LedgerDraft(
    date: now.subtract(Duration(days: daysAgo)),
    amountCents: cents,
    payee: payee,
    categoryId: categoryId,
  );

  test('the list is exactly what Home counts, newest first', () async {
    final id = await account();
    final off = await account(offBudget: true);
    await store.addTransaction(id, draft(-100, payee: 'Older', daysAgo: 5));
    await store.addTransaction(id, draft(-200, payee: 'Newer'));
    await store.addTransaction(id, draft(-300, payee: 'Too old', daysAgo: 40));
    await store.addTransaction(id, draft(-400, payee: 'Sorted', categoryId: 'preset:food.groceries'));
    await store.addTransaction(off, draft(-500, payee: 'Off budget'));

    final reports = LedgerReports(db, store);
    final list = await reports.uncategorized(phoneScope);
    expect(list.map((t) => t.payee), ['Newer', 'Older']);
    expect((await reports.dashboard(phoneScope)).uncategorizedCount, list.length);
  });

  test('a part of a split is listed but marked', () {
    final today = DateTime(2026, 11, 5);
    LedgerTransaction row(String id, {String? parentId, bool isParent = false, int cents = -100}) => LedgerTransaction(
      id: id,
      scope: '',
      accountId: 'a',
      date: '2026-11-01',
      amountCents: cents,
      cleared: false,
      startingBalance: false,
      isParent: isParent,
      parentId: parentId,
      createdAt: 0,
      updatedAt: 0,
      deleted: false,
    );
    final list = buildUncategorized(
      accounts: [
        const LedgerAccount(
          id: 'a',
          scope: '',
          name: 'Checking',
          offBudget: false,
          closed: false,
          sort: 0,
          updatedAt: 0,
          deleted: false,
        ),
      ],
      transactions: [
        row('p', isParent: true, cents: -300),
        row('k1', parentId: 'p'),
      ],
      payeeNames: const {},
      today: today,
    );
    expect(list.map((t) => (t.id, t.inSplit)), [('k1', true)]);
  });

  testWidgets('from Home to the rows, and choosing a category takes one off', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await account();
      await store.addTransaction(id, draft(-100, payee: 'Bakery'));
      await store.addTransaction(id, draft(-150, payee: 'Bakery', daysAgo: 3));
      await store.addTransaction(id, draft(-200, payee: 'Kiosk'));
    });
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: DashboardScreen()),
              ),
              GoRoute(path: '/dashboard/uncategorized', builder: (_, _) => const UncategorizedScreen()),
            ],
          ),
        ),
      ),
    );
    await settle();

    await tester.tap(find.text('3 transactions in the last 30 days without a category'));
    await settle();
    expect(find.text('Without a category'), findsOneWidget);
    expect(find.text('Kiosk'), findsOneWidget);

    expect(find.text('Bakery'), findsNWidgets(2));
    await tester.tap(find.text('Bakery').first);
    await settle();
    await tester.tap(find.text('Groceries'));
    await settle();

    // Both of the payee's rows took it, and the other payee didn't.
    expect(find.text('Bakery'), findsNothing);
    expect(find.text('Kiosk'), findsOneWidget);
    expect(find.text('2 from Bakery moved to Groceries. Next time too.'), findsOneWidget);
    final rows = await tester.runAsync(() => store.transactions(id));
    expect(rows!.where((t) => t.categoryId == presetId('food.groceries')), hasLength(2));
    final memory = LocalCategoryStore(db);
    expect(await tester.runAsync(() => memory.suggest('BAKERY')), isNotNull);

    await tester.tap(find.text('Undo'));
    await settle();
    expect(find.text('Bakery'), findsNWidgets(2));
    expect(await tester.runAsync(() => memory.rememberedCategory('Bakery')), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  test('with Actual the memory goes through a link, or a copy the category sync can send', () async {
    final memory = LocalCategoryStore(db);
    Future<void> category(String id, String name) => db
        .into(db.ledgerCategories)
        .insert(
          LedgerCategoriesCompanion.insert(
            scope: 'b1',
            id: id,
            name: name,
            sort: 0,
            groupId: 'g',
            groupName: 'Everyday',
            groupSort: 0,
          ),
        );
    await category('a-groc', 'Supermercado');
    await category('a-pets', 'Pets');
    await memory.link(presetId('food.groceries'), 'b1', 'a-groc');

    expect(await memory.rememberActual('Lidl', 'b1', 'a-groc'), presetId('food.groceries'));
    expect(await memory.rememberActual('Vet', 'b1', 'a-pets'), 'actual:a-pets');
    expect((await memory.links('b1'))['actual:a-pets'], 'a-pets');
    expect(await memory.rememberedCategory('Vet', budgetSyncId: 'b1'), 'actual:a-pets');
    // The phone's own lists stay free of the copy.
    final own = await memory.allGroups();
    expect(own.expand((g) => g.categories).map((c) => c.id), isNot(contains('actual:a-pets')));
  });
}
