import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/format/money.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/accounts/screens/accounts_settings_screen.dart';

// docs/plans/local-ledger.md, Phase 2: Settings › Accounts.

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Drift answers on real futures, which the test clock doesn't advance
  /// (as in categories_screens_test.dart).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Unmounts the screen so drift's stream closes inside the test (its
  /// close timer would otherwise still be pending).
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light(), home: const AccountsSettingsScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('adding the first account from the empty state', (tester) async {
    await pumpScreen(tester);
    expect(find.text('No accounts yet'), findsOneWidget);

    await tester.tap(find.text('Add account'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Checking');
    await tester.enterText(find.byType(TextField).at(1), '1.250,50');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Checking'), findsOneWidget);
    expect(find.text(formatCents(125050)), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the sheet asks for a name and a real amount', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Add account'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), 'lots');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Give the account a name.'), findsOneWidget);
    expect(find.text('Enter an amount, like 1250,00 or -40.'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.ledgerAccounts).get()), isEmpty);
    await finish(tester);
  });

  testWidgets('editing changes the opening balance, and a closed account moves under Closed', (tester) async {
    final store = LedgerStore(db);
    final id = await tester.runAsync(() => store.createAccount(phoneScope, name: 'Card', openingBalanceCents: -4000));
    await pumpScreen(tester);
    expect(find.text(formatCents(-4000)), findsOneWidget);

    await tester.tap(find.text('Card'));
    await settle(tester);
    expect(find.text('Edit account'), findsOneWidget);
    expect(find.widgetWithText(TextField, '-40,00'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '-55');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text(formatCents(-5500)), findsOneWidget);

    await tester.tap(find.text('Card'));
    await settle(tester);
    await tester.tap(find.text('Close account'));
    await settle(tester);
    expect(find.text('Closed'), findsOneWidget);
    expect((await tester.runAsync(() => store.account(id!)))!.closed, isTrue);
    await finish(tester);
  });

  group('amount input', () {
    test('signed amounts, empty and zero', () {
      expect(parseSignedAmountInput(''), 0);
      expect(parseSignedAmountInput('0,00'), 0);
      expect(parseSignedAmountInput('-40'), -4000);
      expect(parseSignedAmountInput('−1.234,56'), -123456);
      expect(parseSignedAmountInput('12,5'), 1250);
      expect(parseSignedAmountInput('lots'), isNull);
      expect(centsToInput(-4000), '-40,00');
      expect(centsToInput(123456), '1234,56');
      expect(centsToInput(0), '');
    });
  });
}
