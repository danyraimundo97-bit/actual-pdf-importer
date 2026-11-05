import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/categories/screens/categories_screen.dart';
import 'package:mobile_app/features/categories/screens/category_memory_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    // No backend: both screens work from the phone's own database.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Drift answers on real futures, which the test clock doesn't advance.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
  }

  testWidgets("category memory shows the phone's mappings without a backend", (tester) async {
    await tester.runAsync(
      () => container.read(localCategoryStoreProvider).remember('PADARIA CENTRAL', presetId('food.restaurants')),
    );
    await pump(tester, const CategoryMemoryScreen());

    expect(find.text('PADARIA CENTRAL'), findsOneWidget);
    expect(find.text('Restaurants & cafés'), findsOneWidget);
    expect(find.byTooltip('Learn from Actual'), findsNothing, reason: 'that needs Actual');
  });

  group('saving a mapping offers to move the payee\'s existing transactions', () {
    final between = presetId('money.between_accounts');
    final food = presetId('food.groceries');

    Future<String> seed(WidgetTester tester) async => (await tester.runAsync(() async {
      final store = container.read(ledgerStoreProvider);
      await container.read(localCategoryStoreProvider).remember('REVOLUT', food);
      final id = await store.createAccount(phoneScope, name: 'Checking');
      await store.addTransactions(id, [
        LedgerDraft(date: DateTime(2026, 11, 1), amountCents: -5000, payee: 'REVOLUT', categoryId: food),
        // Same payee as far as the memory goes: case and spacing don't matter.
        LedgerDraft(date: DateTime(2026, 11, 2), amountCents: -7000, payee: 'revolut '),
        LedgerDraft(date: DateTime(2026, 11, 3), amountCents: -900, payee: 'BAKERY', categoryId: food),
      ]);
      return id;
    }))!;

    Future<Map<String, String?>> categories(WidgetTester tester, String accountId) async =>
        (await tester.runAsync(() async {
          final store = container.read(ledgerStoreProvider);
          return {for (final t in await store.transactions(accountId)) t.date: t.categoryId};
        }))!;

    Future<void> saveAsBetween(WidgetTester tester) async {
      await tester.tap(find.text('REVOLUT'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await settle(tester);
      await tester.tap(find.text('Between my accounts'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
    }

    testWidgets('moving them changes those rows only, and Undo puts them back', (tester) async {
      final id = await seed(tester);
      await pump(tester, const CategoryMemoryScreen());
      await saveAsBetween(tester);

      expect(find.text('Move existing transactions too?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Move 2'));
      await settle(tester);

      final moved = await categories(tester, id);
      expect(moved['2026-11-01'], between);
      expect(moved['2026-11-02'], between);
      expect(moved['2026-11-03'], food, reason: 'another payee');

      await tester.tap(find.text('Undo'));
      await settle(tester);
      final undone = await categories(tester, id);
      expect(undone['2026-11-01'], food);
      expect(undone['2026-11-02'], isNull);
    });

    testWidgets('"Only future ones" leaves them alone', (tester) async {
      final id = await seed(tester);
      await pump(tester, const CategoryMemoryScreen());
      await saveAsBetween(tester);

      await tester.tap(find.text('Only future ones'));
      await settle(tester);
      expect((await categories(tester, id))['2026-11-01'], food);
    });
  });

  testWidgets('category memory without mappings explains how the phone learns', (tester) async {
    await pump(tester, const CategoryMemoryScreen());

    expect(find.text('Nothing remembered yet'), findsOneWidget);
    expect(find.textContaining('export it'), findsOneWidget);
  });

  testWidgets('categories: hiding one marks it hidden and takes it out of the picker', (tester) async {
    await pump(tester, const CategoriesScreen());
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Groceries'));
    await settle(tester);

    expect(find.byTooltip('Show Groceries'), findsOneWidget);
    final picker = await tester.runAsync(() => container.read(localCategoryStoreProvider).groups());
    expect(picker!.expand((g) => g.categories).map((c) => c.name), isNot(contains('Groceries')));
  });

  testWidgets('categories: choosing an emoji, and choosing none', (tester) async {
    await pump(tester, const CategoriesScreen());
    expect(find.text('🛒'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose an emoji for Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🥖'));
    await settle(tester);
    expect(find.text('🥖'), findsOneWidget);
    expect(find.text('🛒'), findsNothing);

    await tester.tap(find.byTooltip('Choose an emoji for Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No emoji'));
    await settle(tester);
    expect(find.text('🥖'), findsNothing);
    // Its first letter keeps the column.
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('categories: adding one to a group', (tester) async {
    await pump(tester, const CategoriesScreen());

    await tester.tap(find.byTooltip('Add a category to Food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bakery');
    await tester.pump(); // the Add button enables once there's a name
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Bakery'), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
  });
}
