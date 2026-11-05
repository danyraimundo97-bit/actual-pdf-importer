import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/db/local_category_store.dart';
import 'package:mobile_app/data/local/db/preset_categories.dart';
import 'package:mobile_app/data/local/ledger_move.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/local/ledger_sync.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/accounts/screens/move_accounts_screen.dart';
import 'package:mobile_app/features/dashboard/screens/dashboard_screen.dart';

// docs/plans/local-ledger.md, Phase 5c: the phone's own rows go into a budget.

const budget = 'budget-1';

void main() {
  late AppDatabase db;
  late LedgerStore store;
  late LedgerMove move;
  final groceries = presetId('food.groceries');
  final fuel = presetId('transport.fuel');
  final day = DateTime(2026, 10, 15);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LedgerStore(db);
    move = LedgerMove(db);
  });
  tearDown(() => db.close());

  Future<Map<String, dynamic>> emptyPull(String _, String? _, int? _) async => {
    'full': true,
    'epoch': 'e',
    'lastId': 1,
    'accounts': [
      {'id': 'chk', 'name': 'Checking'},
    ],
    'payees': [
      {'id': 'p-bakery', 'name': 'Bakery'},
    ],
    'categories': const [],
    'transactions': const [],
    'budgets': const [],
    'budgetMode': 'envelope',
  };

  Future<void> budgetCopy() => LedgerSync(db, emptyPull).pull(budget);

  test('a new account goes with its opening balance, rows, payees and outbox', () async {
    await budgetCopy();
    final id = await store.createAccount(phoneScope, name: 'Cash', openingBalanceCents: 1000);
    await store.addTransaction(id, LedgerDraft(date: day, amountCents: -500, payee: 'Bakery', categoryId: groceries));
    await store.addTransaction(id, LedgerDraft(date: day, amountCents: -700, payee: 'Newsstand', categoryId: fuel));

    final result = await move.intoBudget(budget, accounts: {id: null}, links: {groceries: 'a-groc'});

    expect(result.accounts, 1);
    expect(result.transactions, 3);
    expect(result.withoutCategory, 1);
    expect(await store.accounts(phoneScope), isEmpty);
    expect(await store.allTransactions(phoneScope), isEmpty);
    expect((await store.accounts(budget)).map((a) => a.name), containsAll(['Checking', 'Cash']));

    final rows = await store.transactions(id);
    final bakery = rows.firstWhere((t) => t.amountCents == -500);
    // The budget's own payee, and the Actual category; never a local id.
    expect(bakery.payeeId, 'p-bakery');
    expect(bakery.categoryId, 'a-groc');
    expect(rows.firstWhere((t) => t.amountCents == -700).categoryId, isNull);

    final outbox = await store.outbox(budget);
    expect(await store.outbox(phoneScope), isEmpty);
    expect(outbox.where((o) => o.kind == 'account').map((o) => o.rowId), [id]);
    expect(outbox.where((o) => o.kind == 'transaction').length, 3);
    // Only the payee Actual doesn't have.
    final payees = outbox.where((o) => o.kind == 'payee').toList();
    expect(payees, hasLength(1));
    expect((await store.payeeNames(budget))[payees.single.rowId], 'Newsstand');
  });

  test('joining an account leaves the opening balance behind and keeps the old id working', () async {
    await budgetCopy();
    final id = await store.createAccount(phoneScope, name: 'Current', openingBalanceCents: 1000);
    final row = await store.addTransaction(id, LedgerDraft(date: day, amountCents: -500, payee: 'Bakery'));

    await move.intoBudget(budget, accounts: {id: 'chk'}, links: const {});

    final rows = await store.transactions('chk');
    expect(rows.map((t) => t.id), [row]);
    expect(await store.account(id), isNotNull); // through the alias
    expect((await store.account(id))!.id, 'chk');
    expect(await store.accounts(phoneScope), isEmpty);
    final outbox = await store.outbox(budget);
    expect(outbox.map((o) => (o.kind, o.rowId)), [('transaction', row)]);
  });

  test('removed rows never go, and an account not chosen stays', () async {
    await budgetCopy();
    final a = await store.createAccount(phoneScope, name: 'Cash');
    final b = await store.createAccount(phoneScope, name: 'Added meanwhile');
    final gone = await store.addTransaction(a, LedgerDraft(date: day, amountCents: -1));
    await store.deleteTransaction(gone!);
    await store.addTransaction(b, LedgerDraft(date: day, amountCents: -2, payee: 'Stays'));

    final result = await move.intoBudget(budget, accounts: {a: null}, links: const {});

    expect(result.transactions, 0);
    expect((await store.accounts(phoneScope)).map((x) => x.id), [b]);
    expect((await store.allTransactions(phoneScope)).single.amountCents, -2);
    expect((await store.payeeNames(phoneScope)).values, contains('Stays'));
    expect((await store.outbox(budget)).any((o) => o.rowId == gone), isFalse);
  });

  test('budget amounts fill empty spots only, and unlinked ones stay', () async {
    await budgetCopy();
    await store.setBudget(budget, 'a-groc', '2026-10', 5000);
    await store.setBudget(phoneScope, groceries, '2026-10', 100);
    await store.setBudget(phoneScope, groceries, '2026-11', 200);
    await store.setBudget(phoneScope, fuel, '2026-10', 300);

    final result = await move.intoBudget(budget, accounts: const {}, links: {groceries: 'a-groc'});

    expect(result.budgets, 1);
    expect(await store.budgets(budget, '2026-10'), {'a-groc': 5000});
    expect(await store.budgets(budget, '2026-11'), {'a-groc': 200});
    expect(await store.budgets(phoneScope, '2026-10'), {fuel: 300});
  });

  test('then the sync sends it, in order, and a pull before the answer changes nothing', () async {
    await budgetCopy();
    final id = await store.createAccount(phoneScope, name: 'Cash', openingBalanceCents: 1000);
    await store.addTransaction(id, LedgerDraft(date: day, amountCents: -500, payee: 'Newsstand'));
    await move.intoBudget(budget, accounts: {id: null}, links: const {});

    // Actual hasn't heard of the account yet: a pull must not lose it.
    await LedgerSync(db, emptyPull).pull(budget);
    expect((await store.accounts(budget)).map((a) => a.id), contains(id));
    expect(await store.transactions(id), hasLength(2));

    final sent = <String>[];
    var next = 1;
    final sync = LedgerSync(
      db,
      emptyPull,
      send: (_, entries) async => [
        for (final e in entries)
          () {
            sent.add(e['kind'] as String);
            expect(e['categoryId'], isNull);
            return {'seq': e['seq'], 'ok': true, 'id': 'actual-${next++}'};
          }(),
      ],
    );
    final pushed = await sync.push(budget);

    expect(pushed.failed, 0);
    expect(sent, ['payee', 'account', 'transaction', 'transaction']);
    expect(await store.outbox(budget), isEmpty);
  });

  test('the phone rows count as categories in use, so they get matched', () async {
    final categories = LocalCategoryStore(db);
    final id = await store.createAccount(phoneScope, name: 'Cash');
    await store.addTransaction(id, LedgerDraft(date: day, amountCents: -500, categoryId: groceries));
    await store.setBudget(phoneScope, fuel, '2026-10', 300);

    final used = await categories.categoriesInUse(budgetSyncId: budget);
    expect(used, containsAll([groceries, fuel]));
  });

  group('on screen', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'budget_sync_id': budget, 'budget_name': 'Family'});
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: DashboardScreen()),
          ),
          GoRoute(path: '/move-accounts', builder: (_, _) => const MoveAccountsScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            linkStateProvider.overrideWith((ref) async => LinkState.ready),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('Home offers it, and the screen moves the rows', (tester) async {
      await tester.runAsync(() async {
        await budgetCopy();
        final id = await store.createAccount(phoneScope, name: 'Cash', openingBalanceCents: 1000);
        await store.addTransaction(id, LedgerDraft(date: day, amountCents: -500, payee: 'Bakery'));
      });
      await pump(tester);
      expect(find.text('One account is only on this phone'), findsOneWidget);

      await tester.tap(find.text('Bring them over'));
      await settle(tester);
      expect(find.text('Bring accounts over'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      // Nothing moved by opening it.
      expect(await tester.runAsync(() => store.accounts(phoneScope)), hasLength(1));

      await tester.tap(find.widgetWithText(FilledButton, 'Bring them over'));
      await settle(tester);

      expect(find.text('One account is only on this phone'), findsNothing);
      expect(await tester.runAsync(() => store.accounts(phoneScope)), isEmpty);
      final outbox = await tester.runAsync(() => store.outbox(budget));
      expect(outbox!.map((o) => o.kind).toSet(), {'account', 'transaction'});
      await finish(tester);
    });

    testWidgets('"Not now" stays dismissed for the budget', (tester) async {
      await tester.runAsync(() async {
        await budgetCopy();
        final id = await store.createAccount(phoneScope, name: 'Cash');
        await store.addTransaction(id, LedgerDraft(date: day, amountCents: -500));
      });
      await pump(tester);
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.text('One account is only on this phone'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().any((k) => k.contains('dismissed') && k.endsWith(budget)), isTrue);
      await finish(tester);
    });
  });
}
