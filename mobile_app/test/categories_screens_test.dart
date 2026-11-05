import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
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
