import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/format/money.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/ledger_builders.dart';
import 'package:mobile_app/data/local/ledger_reports.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/budget/screens/budget_screen.dart';
import 'package:mobile_app/features/budget/screens/budget_style_screen.dart';

// docs/plans/local-ledger.md, Phase 7: the budget style setting and the guide.

void main() {
  late AppDatabase db;
  late LedgerStore store;
  final groceries = presetId('food.groceries');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LedgerStore(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool actual = false,
    Size size = const Size(600, 1600),
    double textScale = 1,
    bool dark = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (actual) ...{'budget_sync_id': 'casa', 'budget_name': 'Casa'},
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          linkStateProvider.overrideWith((ref) async => actual ? LinkState.ready : LinkState.noBackend),
        ],
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => home),
              GoRoute(path: '/settings/budget-guide', builder: (_, _) => const BudgetGuideScreen()),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('the setting', () {
    testWidgets("the phone's budget starts on simple limits, and choosing Envelopes is saved", (tester) async {
      await pump(tester, const BudgetStyleScreen());
      expect(await tester.runAsync(() => store.budgetMode(phoneScope)), isNull);

      await tester.tap(find.text('Envelopes'));
      await settle(tester);
      expect(await tester.runAsync(() => store.budgetMode(phoneScope)), 'envelope');
      await finish(tester);
    });

    test('changing it changes the totals and leaves the amounts', () async {
      final reports = LedgerReports(db, store, now: () => DateTime(2026, 11, 5));
      final id = await store.createAccount(phoneScope, name: 'Checking');
      await store.addTransaction(
        id,
        LedgerDraft(date: DateTime(2026, 10, 10), amountCents: -25000, categoryId: groceries),
      );
      await store.setBudget(phoneScope, groceries, '2026-10', 30000);
      await store.setBudget(phoneScope, groceries, '2026-11', 30000);

      Future<int> november() async => (await reports.budgetMonth(
        phoneScope,
        '2026-11',
      )).groups.expand((g) => g.categories).firstWhere((c) => c.id == groceries).balanceCents;

      expect(await november(), 30000);
      await store.setBudgetMode(phoneScope, BudgetStyle.envelope.name);
      expect(await november(), 35000);
      expect(await store.budgets(phoneScope, '2026-11'), {groceries: 30000});
    });

    testWidgets("with Actual it says which it is and offers no choice", (tester) async {
      await tester.runAsync(() => store.setBudgetMode('casa', 'tracking'));
      await pump(tester, const BudgetStyleScreen(), actual: true);

      expect(find.text('Simple monthly limits'), findsOneWidget);
      expect(find.text('Envelopes'), findsNothing);
      expect(find.textContaining('set in Actual'), findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('the guide shows the example in both styles', (tester) async {
    await pump(tester, const BudgetGuideScreen());
    expect(find.text('Simple monthly limits'), findsOneWidget);
    expect(find.text('Envelopes'), findsOneWidget);
    expect(find.text(formatBalance(30000)), findsOneWidget);
    expect(find.text(formatBalance(35000)), findsOneWidget);
    await finish(tester);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('the guide and the setting at 320dp with 2x text ($mode): nothing overflows', (tester) async {
      await pump(tester, const BudgetGuideScreen(), size: const Size(320, 640), textScale: 2, dark: dark);
      expect(tester.takeException(), isNull);
      await pump(tester, const BudgetStyleScreen(), size: const Size(320, 640), textScale: 2, dark: dark);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    for (final style in BudgetStyle.values) {
      testWidgets('the Budget tab, ${style.name}, at 320dp with 2x text ($mode): nothing overflows', (tester) async {
        await tester.runAsync(() async {
          await store.setBudgetMode(phoneScope, style.name);
          final id = await store.createAccount(phoneScope, name: 'Checking');
          await store.addTransaction(
            id,
            LedgerDraft(date: DateTime.now(), amountCents: -25000, payee: 'Market', categoryId: groceries),
          );
          await store.setBudget(phoneScope, groceries, ledgerMonthKeys(DateTime.now(), 1).single, 30000);
        });
        await pump(
          tester,
          const Scaffold(body: BudgetScreen()),
          size: const Size(320, 640),
          textScale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await finish(tester);
      });
    }
  }
}
