import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/local/ledger_sync.dart';
import 'package:mobile_app/data/models/actual_account.dart';
import 'package:mobile_app/data/models/actual_category.dart';
import 'package:mobile_app/data/models/budget_month.dart';
import 'package:mobile_app/data/models/quick_add.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/budget/screens/budget_screen.dart';
import 'package:mobile_app/features/quick_add/quick_add_controller.dart';
import 'package:mobile_app/features/quick_add/screens/quick_add_screen.dart';

const _options = QuickAddOptions(
  accounts: [
    ActualAccount(id: 'chk', name: 'Checking', offbudget: false, closed: false),
    ActualAccount(id: 'cash', name: 'Cash', offbudget: false, closed: false),
  ],
  categoryGroups: [
    ActualCategoryGroup(
      id: 'food',
      name: 'Food',
      categories: [ActualCategory(id: 'groc', name: 'Groceries')],
    ),
    ActualCategoryGroup(
      id: 'inc',
      name: 'Income',
      categories: [ActualCategory(id: 'sal', name: 'Salary')],
    ),
  ],
  incomeGroupIds: {'inc'},
  recentPayees: [
    RecentPayee(name: 'Lidl', lastCategoryId: 'groc'),
    RecentPayee(name: 'Café'),
  ],
);

const _budget = 'casa';

/// A phone with a pulled copy of the budget, or (with [connected] false)
/// the phone's own budget and no backend at all.
Future<(ProviderContainer, AppDatabase, SharedPreferences)> _container({
  Map<String, Object> prefs = const {},
  bool connected = true,
}) async {
  SharedPreferences.setMockInitialValues({if (connected) 'budget_sync_id': _budget, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(overrides: _overrides(sp, db, connected: connected));
  addTearDown(container.dispose);
  // Keep the auto-dispose controller alive for the whole test.
  container.listen(quickAddControllerProvider, (_, _) {});
  return (container, db, sp);
}

List<Override> _overrides(SharedPreferences sp, AppDatabase db, {required bool connected}) => [
  sharedPreferencesProvider.overrideWithValue(sp),
  appDatabaseProvider.overrideWithValue(db),
  linkStateProvider.overrideWith((ref) async => connected ? LinkState.ready : LinkState.noBackend),
];

Future<void> _seedCopy(AppDatabase db) async {
  await LedgerSync(db, (_, _, _) async {
    return {
      'epoch': 'e1',
      'lastId': 1,
      'full': true,
      'budgetType': 'envelope',
      'accounts': [
        {'id': 'chk', 'name': 'Checking', 'offbudget': false, 'closed': false},
      ],
      'categoryGroups': [
        {
          'id': 'food',
          'name': 'Food',
          'isIncome': false,
          'hidden': false,
          'categories': [
            {'id': 'groc', 'name': 'Groceries', 'hidden': false},
          ],
        },
      ],
      'payees': [
        {'id': 'p1', 'name': 'Lidl', 'transferAccountId': null},
      ],
      'transactions': [
        {
          'id': 't1',
          'accountId': 'chk',
          'date': '2026-10-01',
          'amountCents': -1000,
          'payeeId': 'p1',
          'categoryId': 'groc',
          'notes': null,
          'cleared': false,
          'importedId': null,
          'startingBalance': false,
          'transferId': null,
          'parentId': null,
          'isParent': false,
          'deleted': false,
        },
      ],
      'budgets': [],
    };
  }).pull(_budget);
}

void main() {
  test('parseAmountInput reads Portuguese and English formats, positive only', () {
    expect(parseAmountInput('4,50'), 450);
    expect(parseAmountInput('4.5'), 450);
    expect(parseAmountInput('12'), 1200);
    expect(parseAmountInput('1.234,56'), 123456);
    expect(parseAmountInput('1,234.56'), 123456);
    expect(parseAmountInput('1.234'), 123400, reason: 'three digits after the dot = thousands');
    expect(parseAmountInput(' -4,50 € '), 450, reason: 'the sign comes from the toggle');
    expect(parseAmountInput('0'), isNull);
    expect(parseAmountInput(''), isNull);
    expect(parseAmountInput('4,5,6'), isNull);
    expect(parseAmountInput('abc'), isNull);
  });

  test('newClientId is a v4 UUID and different each time', () {
    final a = newClientId();
    expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(newClientId(), isNot(a));
  });

  test('expense by default; income flips the sign and clears an expense category', () async {
    final (c, _, _) = await _container();
    final controller = c.read(quickAddControllerProvider.notifier);
    controller.setAmount('4,50');
    controller.setCategory('groc', 'Groceries');
    expect(c.read(quickAddControllerProvider).amountCents, -450);

    controller.setIncome(true);
    final state = c.read(quickAddControllerProvider);
    expect(state.amountCents, 450);
    expect(state.categoryId, isNull);
  });

  test('a known payee pre-fills its last category, unless one was chosen', () async {
    final (c, _, _) = await _container();
    final controller = c.read(quickAddControllerProvider.notifier);
    controller.setPayee('lidl', options: _options);
    expect(c.read(quickAddControllerProvider).categoryName, 'Groceries');

    controller.setPayee('Somewhere new', options: _options);
    expect(c.read(quickAddControllerProvider).categoryId, isNull);

    controller.setCategory('sal', 'Salary');
    controller.setPayee('Lidl', options: _options);
    expect(c.read(quickAddControllerProvider).categoryId, 'sal');
  });

  test('the account defaults to the last one used, else the first', () async {
    final (c, _, _) = await _container(prefs: {'last_account_id': 'cash'});
    c.read(quickAddControllerProvider.notifier).applyOptions(_options);
    expect(c.read(quickAddControllerProvider).accountId, 'cash');

    final (c2, _, _) = await _container(prefs: {'last_account_id': 'gone'});
    c2.read(quickAddControllerProvider.notifier).applyOptions(_options);
    expect(c2.read(quickAddControllerProvider).accountId, 'chk');
  });

  test('saving twice from one form adds it once', () async {
    final (c, db, sp) = await _container();
    await _seedCopy(db);
    final store = LedgerStore(db);
    final options = await c.read(quickAddOptionsProvider.future);
    final controller = c.read(quickAddControllerProvider.notifier)..applyOptions(options);
    controller.setAmount('4,50');
    controller.setPayee('Café', options: options);

    expect(await controller.save(), isTrue);
    expect(await controller.save(), isTrue);

    final added = (await store.transactions('chk')).where((t) => t.amountCents == -450).toList();
    expect(added, hasLength(1));
    expect(added.single.importedId, 'app-${c.read(quickAddControllerProvider).clientId}');
    expect(await store.watchOutboxSummary(_budget).first, (waiting: 2, failed: 0), reason: 'waits for the sync');
    expect(sp.getString('last_account_id'), 'chk');
  });

  test('a save that fails keeps the form and says so', () async {
    final (c, db, _) = await _container();
    await _seedCopy(db);
    final controller = c.read(quickAddControllerProvider.notifier);
    controller.setAmount('4,50');
    controller.setAccount('no-such-account');
    expect(await controller.save(), isFalse);
    expect(c.read(quickAddControllerProvider).error, isNotNull);
    expect(c.read(quickAddControllerProvider).amountText, '4,50');
  });

  test("without Actual it offers the phone's accounts and categories, and saves there", () async {
    final (c, db, _) = await _container(connected: false);
    final store = LedgerStore(db);
    final id = await store.createAccount(phoneScope, name: 'Wallet');
    final options = await c.read(quickAddOptionsProvider.future);
    expect([for (final a in options.accounts) a.id], [id]);
    expect(options.categoryGroups, isNotEmpty);

    final groceries = options.categoryGroups.expand((g) => g.categories).firstWhere((x) => x.name == 'Groceries');
    final controller = c.read(quickAddControllerProvider.notifier)..applyOptions(options);
    controller.setAmount('12');
    controller.setPayee('Corner shop', options: options);
    controller.setCategory(groceries.id, groceries.name);
    expect(await controller.save(), isTrue);

    final row = (await store.transactions(id)).single;
    expect((row.scope, row.amountCents, row.categoryId), (phoneScope, -1200, groceries.id));
    final local = LocalCategoryStore(db);
    expect((await local.suggest('Corner shop'))?.categoryId, groceries.id, reason: 'teaches the memory');
  });

  test('with Actual unreachable, a budget with a copy stays on screen', () async {
    SharedPreferences.setMockInitialValues({'budget_sync_id': _budget});
    final sp = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedCopy(db);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(db),
        linkStateProvider.overrideWith(
          (ref) async => throw const ApiException(message: 'Could not reach the backend.'),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(quickAddOptionsProvider, (_, _) {});
    final options = await c.read(quickAddOptionsProvider.future);
    expect([for (final a in options.accounts) a.id], ['chk']);
    expect(await c.read(ledgerScopeProvider.future), _budget);
  });

  group('the screen', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    Future<AppDatabase> pump(
      WidgetTester tester, {
      required bool connected,
      Map<String, Object> prefs = const {},
      Widget home = const QuickAddScreen(),
    }) async {
      SharedPreferences.setMockInitialValues({if (connected) 'budget_sync_id': _budget, ...prefs});
      final sp = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      if (connected) await tester.runAsync(() => _seedCopy(db));
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(sp, db, connected: connected),
          child: MaterialApp(home: Scaffold(body: home)),
        ),
      );
      await settle(tester);
      return db;
    }

    testWidgets('without Actual it never asks to connect: it offers to add an account', (tester) async {
      await pump(tester, connected: false);
      expect(find.textContaining('Connect'), findsNothing);
      expect(find.text('Add an account first'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a budget amount set on a copy of Actual waits to be sent, and the line says so', (tester) async {
      final db = await pump(tester, connected: true, home: const BudgetScreen());
      expect(find.textContaining('waiting'), findsNothing);
      await tester.tap(find.text('Set budget').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, '250');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('1 change waiting'), findsOneWidget);
      final waiting = await tester.runAsync(() => LedgerStore(db).outbox(_budget));
      expect((waiting!.single.kind, waiting.single.rowId.startsWith('groc|')), ('budget', true));
      await finish(tester);
    });

    testWidgets('type an amount, pick a known payee, save', (tester) async {
      final db = await pump(tester, connected: true);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, '12,30');
      await tester.enterText(find.byType(TextField).at(1), 'Lid');
      await settle(tester);
      await tester.tap(find.text('Lidl').last);
      await settle(tester);
      // An Actual category named like one of the phone's takes its emoji.
      expect(find.text('🛒 Groceries'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);
      final rows = await tester.runAsync(() => LedgerStore(db).transactions('chk'));
      final row = rows!.firstWhere((t) => t.amountCents == -1230);
      expect((row.payeeId, row.categoryId), ('p1', 'groc'));
      expect(row.importedId, startsWith('app-'));
      await finish(tester);
    });
  });

  test('BudgetCategory.usedFraction', () {
    BudgetCategory c(int spent, int balance) =>
        BudgetCategory(id: 'c', name: 'c', budgetedCents: 0, spentCents: spent, balanceCents: balance);
    expect(c(0, 1000).usedFraction, 0);
    expect(c(-250, 750).usedFraction, 0.25);
    expect(c(-1200, -200).usedFraction, 1);
    expect(c(-100, -100).usedFraction, 1, reason: 'nothing was available');
  });
}
