import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/format/dates.dart';
import 'package:mobile_app/core/format/money.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/ledger_builders.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/accounts/screens/account_screen.dart';
import 'package:mobile_app/features/budget/screens/budget_screen.dart';
import 'package:mobile_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:mobile_app/shared/widgets/pressable.dart';

// docs/plans/local-ledger.md, Phase 4: Home, Budget and the account screen
// with no backend at all, read from the phone's own ledger.

void main() {
  late AppDatabase db;
  late LedgerStore store;
  final now = DateTime.now();
  final month = ledgerMonthKeys(now, 1).single;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LedgerStore(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    await settle(tester);
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() body) async => (await tester.runAsync(body)) as T;

  group('Home', () {
    testWidgets('with no accounts it asks for one first', (tester) async {
      await pump(tester, const DashboardScreen());
      expect(find.text('Start with your accounts'), findsOneWidget);
      expect(find.text('Add an account'), findsOneWidget);
      expect(find.textContaining('Connect'), findsNothing);
      await finish(tester);
    });

    testWidgets('shows the phone accounts, net worth and this month', (tester) async {
      await run(tester, () async {
        final id = await store.createAccount(phoneScope, name: 'Checking', openingBalanceCents: 100000);
        await store.addTransactions(id, [
          LedgerDraft(date: now, amountCents: -4250, payee: 'Bakery', categoryId: 'preset:food.groceries'),
        ]);
      });
      await pump(tester, const DashboardScreen());

      expect(find.text('Kept on this phone'), findsOneWidget);
      expect(find.text(formatBalance(95750)), findsWidgets); // net worth, without a plus
      expect(find.text('Checking'), findsWidgets);
      expect(find.text('Bakery'), findsWidgets); // latest transactions and top payees
      expect(find.text(formatCents(-4250)), findsWidgets);
      await finish(tester);
    });
  });

  group('Budget', () {
    testWidgets('tapping a category\'s amount sets it for the month', (tester) async {
      await run(tester, () async {
        final id = await store.createAccount(phoneScope, name: 'Checking');
        await store.addTransactions(id, [
          LedgerDraft(date: now, amountCents: -4000, categoryId: 'preset:food.groceries'),
        ]);
      });
      await pump(tester, const BudgetScreen());
      expect(find.text('Kept on this phone'), findsOneWidget);

      await tester.tap(
        find.descendant(of: find.ancestor(of: find.text('Groceries'), matching: find.byType(Pressable)).first, matching: find.text('Set budget')),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), '250');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(await run(tester, () => store.budgets(phoneScope, month)), {'preset:food.groceries': 25000});
      expect(find.text(formatBalance(21000)), findsWidgets);
      await finish(tester);
    });
  });

  group('Budget rows', () {
    testWidgets('an unused category is one quiet line; a used one shows spent and the chip', (tester) async {
      await run(tester, () async {
        final id = await store.createAccount(phoneScope, name: 'Checking');
        await store.addTransactions(id, [
          LedgerDraft(date: now, amountCents: -4000, categoryId: 'preset:food.groceries'),
        ]);
        await store.setBudget(phoneScope, 'preset:food.groceries', month, 3000);
      });
      await pump(tester, const BudgetScreen());
      expect(find.textContaining('Overspent by'), findsOneWidget);
      expect(find.text(formatBalance(3000)), findsNWidgets(2)); // the summary and the chip
      expect(find.text('Utilities'), findsOneWidget);
      expect(find.text('Set budget'), findsWidgets);
      await finish(tester);
    });

    testWidgets('a folded group stays folded on another month, and the skeleton never flashes', (tester) async {
      await run(tester, () => store.setBudget(phoneScope, 'preset:food.groceries', month, 3000));
      await pump(tester, const BudgetScreen());
      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Food'));
      await settle(tester);
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.bySemanticsLabel('Loading budget'), findsNothing);
      await settle(tester);
      expect(find.text(monthLabel(shiftMonth(month, 1))), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      await finish(tester);
    });
  });

  group('labels', () {
    test('a balance shows no plus; a movement does', () {
      expect(formatBalance(1250).startsWith('+'), isFalse);
      expect(formatBalance(-1250).startsWith('−'), isTrue);
      expect(formatCents(1250).startsWith('+'), isTrue);
    });

    test('days read as words when they can', () {
      final today = DateTime(2026, 3, 1);
      expect(dayLabel(today, now: today), 'Today');
      expect(dayLabel(DateTime(2026, 2, 28), now: today), 'Yesterday');
      expect(dayLabel(DateTime(2026, 2, 27), now: today), '27/02/2026');
    });
  });

  group('Account', () {
    testWidgets('a row can be changed and removed; the balance follows', (tester) async {
      late String id;
      await run(tester, () async {
        id = await store.createAccount(phoneScope, name: 'Checking', openingBalanceCents: 10000);
        await store.addTransactions(id, [LedgerDraft(date: now, amountCents: -1500, payee: 'Bakery')]);
      });
      await pump(tester, AccountScreen(accountId: id));
      expect(find.text(formatCents(8500)), findsOneWidget);

      await tester.tap(find.text('Bakery'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '-15,00'), '-20');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text(formatCents(8000)), findsOneWidget);

      await tester.tap(find.text('Bakery'));
      await settle(tester);
      await tester.tap(find.text('Remove transaction'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(tester);
      expect(find.text('Bakery'), findsNothing);
      expect(find.text(formatCents(10000)), findsWidgets);

      // The opening balance isn't edited here.
      await tester.tap(find.text('Opening balance'));
      await settle(tester);
      expect(find.text('Edit transaction'), findsNothing);
      await finish(tester);
    });
  });
}
