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
import 'package:mobile_app/features/accounts/screens/account_screen.dart';
import 'package:mobile_app/features/budget/screens/month_transactions_screen.dart';

void main() {
  late AppDatabase db;
  late LedgerStore store;

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

  group('LedgerStore.setBalance', () {
    Future<String> account() => store.createAccount(phoneScope, name: 'Checking', openingBalanceCents: 10000);

    test('adds the difference once, cleared, uncategorized and queued for the sync', () async {
      final id = await account();
      final before = (await store.outbox(phoneScope)).length;
      final on = DateTime(2026, 11, 5);

      expect(await store.setBalance(id, 12050, on: on), 2050);

      final added = (await store.transactions(id)).firstWhere((t) => t.notes == balanceAdjustmentNote);
      expect(added.amountCents, 2050);
      expect(added.date, '2026-11-05');
      expect(added.cleared, isTrue);
      expect(added.categoryId, isNull);
      expect(added.payeeId, isNull);
      expect(added.importedId, startsWith('app-'));
      expect((await store.outbox(phoneScope)).length, before + 1);
    });

    test('goes down as well as up, and to a negative balance', () async {
      final id = await account();
      expect(await store.setBalance(id, -500, on: DateTime(2026, 11, 5)), -10500);
      expect((await store.watchAccounts(phoneScope).first).single.balanceCents, -500);
    });

    test('adds nothing when the balance is already right', () async {
      final id = await account();
      final rows = (await store.transactions(id)).length;
      expect(await store.setBalance(id, 10000, on: DateTime(2026, 11, 5)), 0);
      expect((await store.transactions(id)).length, rows);
    });
  });

  testWidgets('Set balance from the account screen adjusts it, with no backend', (tester) async {
    final id = await run(tester, () => store.createAccount(phoneScope, name: 'Checking', openingBalanceCents: 10000));
    await pump(tester, AccountScreen(accountId: id));

    await tester.tap(find.text('Set balance'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '120,50');
    await tester.pump();
    expect(find.textContaining('Adjustment: ${formatCents(2050)}'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(find.text(balanceAdjustmentNote), findsOneWidget);
    expect(find.text(formatCents(12050)), findsOneWidget);
    expect(find.textContaining('Added an adjustment'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a balance of zero can be set, and a negative one with the toggle', (tester) async {
    final id = await run(tester, () => store.createAccount(phoneScope, name: 'Checking', openingBalanceCents: 10000));
    await pump(tester, AccountScreen(accountId: id));

    await tester.tap(find.text('Set balance'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(await run(tester, () async => (await store.watchAccounts(phoneScope).first).single.balanceCents), 0);

    await tester.tap(find.text('Set balance'));
    await settle(tester);
    await tester.tap(find.text('Negative'));
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(await run(tester, () async => (await store.watchAccounts(phoneScope).first).single.balanceCents), -500);
    await finish(tester);
  });

  testWidgets('All transactions lists the month across accounts, with its totals', (tester) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await run(tester, () async {
      final checking = await store.createAccount(phoneScope, name: 'Checking');
      final savings = await store.createAccount(phoneScope, name: 'Savings');
      await store.addTransactions(checking, [
        LedgerDraft(date: DateTime(now.year, now.month, 1), amountCents: -450, payee: 'Bakery'),
        // Last month: not on this screen.
        LedgerDraft(date: DateTime(now.year, now.month - 1, 15), amountCents: -999, payee: 'Old shop'),
      ]);
      await store.addTransactions(savings, [
        LedgerDraft(date: DateTime(now.year, now.month, 1), amountCents: 200000, payee: 'Work'),
      ]);
    });
    await pump(tester, MonthTransactionsScreen(month: month));

    expect(find.text('2 transactions'), findsOneWidget);
    expect(find.text('Bakery'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Old shop'), findsNothing);
    expect(find.text('Checking · Uncategorized'), findsOneWidget);
    expect(find.textContaining('In ${formatCents(200000)}'), findsOneWidget);
    expect(find.textContaining('Out ${formatCents(-450)}'), findsOneWidget);

    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
    expect(next.onPressed, isNull);

    await tester.tap(find.byTooltip('Previous month'));
    await settle(tester);
    expect(find.text('Old shop'), findsOneWidget);
    expect(find.text('Bakery'), findsNothing);
    await finish(tester);
  });
}
