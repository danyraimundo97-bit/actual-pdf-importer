import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/local/db/app_database.dart';
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

    await tester.tap(find.text('2 transactions in the last 30 days without a category'));
    await settle();
    expect(find.text('Without a category'), findsOneWidget);
    expect(find.text('Bakery'), findsOneWidget);
    expect(find.text('Kiosk'), findsOneWidget);

    await tester.tap(find.text('Bakery'));
    await settle();
    await tester.tap(find.text('Groceries'));
    await settle();

    expect(find.text('Bakery'), findsNothing);
    expect(find.text('Kiosk'), findsOneWidget);
    expect(find.text('Moved to Groceries.'), findsOneWidget);
    final rows = await tester.runAsync(() => store.transactions(id));
    expect(rows!.firstWhere((t) => t.amountCents == -100).categoryId, 'preset:food.groceries');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
