import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/ledger_reports.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/local/ledger_sync.dart';
import 'package:sqlite3/sqlite3.dart';

// docs/plans/local-ledger.md, Phase 5: the phone's copy of an Actual budget.

const budget = 'budget-1';

Map<String, dynamic> tx(
  String id, {
  String account = 'chk',
  int cents = -1250,
  bool deleted = false,
  String? category,
}) => {
  'id': id,
  'accountId': account,
  'date': '2026-10-03',
  'amountCents': cents,
  'payeeId': 'p1',
  'categoryId': category,
  'notes': null,
  'cleared': false,
  'importedId': null,
  'startingBalance': false,
  'transferId': null,
  'parentId': null,
  'isParent': false,
  'deleted': deleted,
};

Map<String, dynamic> pull({
  bool full = true,
  int lastId = 10,
  List<Map<String, dynamic>> transactions = const [],
  List<Map<String, dynamic>> budgets = const [],
  List<Map<String, dynamic>>? accounts,
  String budgetType = 'envelope',
}) => {
  'epoch': 'e1',
  'lastId': lastId,
  'full': full,
  'budgetType': budgetType,
  'accounts':
      accounts ??
      [
        {'id': 'chk', 'name': 'Checking', 'offbudget': false, 'closed': false},
        {'id': 'sav', 'name': 'Savings', 'offbudget': true, 'closed': false},
      ],
  'categoryGroups': [
    {
      'id': 'g-food',
      'name': 'Food',
      'isIncome': false,
      'hidden': false,
      'categories': [
        {'id': 'groceries', 'name': 'Groceries', 'hidden': false},
        {'id': 'old', 'name': 'Old', 'hidden': true},
      ],
    },
    {
      'id': 'g-income',
      'name': 'Income',
      'isIncome': true,
      'hidden': false,
      'categories': [
        {'id': 'salary', 'name': 'Salary', 'hidden': false},
      ],
    },
  ],
  'payees': [
    {'id': 'p1', 'name': 'Bakery', 'transferAccountId': null},
  ],
  'transactions': transactions,
  'budgets': budgets,
};

void main() {
  late AppDatabase db;
  late LedgerStore store;
  final requests = <(String?, int?)>[];
  final responses = <Map<String, dynamic>>[];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LedgerStore(db);
    requests.clear();
    responses.clear();
  });
  tearDown(() => db.close());

  LedgerSync sync() => LedgerSync(db, (budgetSyncId, epoch, lastId) async {
    expect(budgetSyncId, budget);
    requests.add((epoch, lastId));
    return responses.removeAt(0);
  }, now: () => DateTime(2026, 10, 20, 12));

  Future<List<LedgerTransaction>> live() =>
      (db.select(db.ledgerTransactions)..where((t) => t.scope.equals(budget) & t.deleted.equals(false))).get();

  test('a first pull copies the budget and keeps the cursor for the next one', () async {
    responses
      ..add(
        pull(
          transactions: [
            tx('t1', category: 'groceries'),
            tx('t2', cents: 200000, category: 'salary'),
          ],
          budgets: [
            {'month': '2026-10', 'categoryId': 'groceries', 'budgetedCents': 30000, 'carryover': false},
          ],
        ),
      )
      ..add(pull(full: false, lastId: 12, transactions: [tx('t1', deleted: true), tx('t3', cents: -500)]));

    expect(await sync().lastPulledAt(budget), isNull);
    final first = await sync().pull(budget);
    expect((first.full, first.transactions, first.budgets), (true, 2, 1));
    expect(await sync().lastPulledAt(budget), DateTime(2026, 10, 20, 12));

    final second = await sync().pull(budget);
    expect(second.full, isFalse);
    expect(requests, [(null, null), ('e1', 10)]);
    expect({for (final t in await live()) t.id}, {'t2', 't3'});

    // The Budget tab reads the copy with Actual's categories and mode.
    final month = await LedgerReports(db, store, now: () => DateTime(2026, 10, 20)).budgetMonth(budget, '2026-10');
    expect([for (final g in month.groups) g.name], ['Food']);
    expect([for (final c in month.groups.single.categories) c.name], ['Groceries'], reason: 'hidden left out');
    expect(month.incomeCents, 200000);
    expect(month.groups.single.categories.single.budgetedCents, 30000);
  });

  test('a full pull replaces what was there; scopes stay apart', () async {
    await store.createAccount(phoneScope, name: 'Phone account');
    responses
      ..add(pull(transactions: [tx('t1'), tx('t2')]))
      ..add(pull(transactions: [tx('t2')]));
    await sync().pull(budget);
    await sync().pull(budget);

    expect([for (final t in await live()) t.id], ['t2']);
    final phone = await store.accounts(phoneScope);
    expect([for (final a in phone) a.name], ['Phone account']);
  });

  test("rows with a change waiting to go to Actual keep the phone's version", () async {
    responses.add(pull(transactions: [tx('t1', cents: -1000)]));
    await sync().pull(budget);
    // An edit on the phone (Phase 5b sends it); Actual meanwhile still has
    // the old amount.
    await store.updateTransaction('t1', amountCents: -2000);
    responses.add(pull(full: false, transactions: [tx('t1', cents: -1000)]));
    await sync().pull(budget);

    expect((await store.transaction('t1'))!.amountCents, -2000);
  });

  test('an account Actual removed is marked removed; its rows keep a stand-in', () async {
    responses.add(
      pull(
        transactions: [
          tx('t1'),
          tx('t9', account: 'gone'),
        ],
      ),
    );
    await sync().pull(budget);
    responses.add(
      pull(
        full: false,
        accounts: [
          {'id': 'chk', 'name': 'Main', 'offbudget': false, 'closed': true},
        ],
      ),
    );
    await sync().pull(budget);

    final accounts = {for (final a in await (db.select(db.ledgerAccounts)).get()) a.id: a};
    expect((accounts['chk']!.name, accounts['chk']!.closed, accounts['chk']!.deleted), ('Main', true, false));
    expect(accounts['sav']!.deleted, isTrue);
    expect(accounts['gone']!.deleted, isTrue);
  });

  test('the budget mode comes from Actual', () async {
    responses.add(pull(budgetType: 'tracking'));
    await sync().pull(budget);
    expect(await store.budgetMode(budget), 'tracking');
  });

  test('upgrading from schema 3 keeps the rows and allows a repeated importedId', () async {
    final dir = Directory.systemTemp.createTempSync('ledger-migration-4-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    // A schema 4 file made to look like schema 3: the categories table
    // dropped, and the transactions table back to its schema 3 form.
    final current = AppDatabase(NativeDatabase(file));
    final id = await LedgerStore(current).createAccount(phoneScope, name: 'Checking', openingBalanceCents: 100);
    await current.close();
    final raw = sqlite3.open(file.path);
    final ddl = raw.select("SELECT sql FROM sqlite_master WHERE name = 'ledger_transactions'").single['sql'] as String;
    raw
      ..execute('DROP TABLE ledger_categories')
      ..execute('DROP INDEX ledger_transactions_account_imported')
      ..execute('ALTER TABLE ledger_transactions RENAME TO old_transactions')
      ..execute('${ddl.substring(0, ddl.lastIndexOf(')'))}, UNIQUE(account_id, imported_id))')
      ..execute('INSERT INTO ledger_transactions SELECT * FROM old_transactions')
      ..execute('DROP TABLE old_transactions')
      ..execute('PRAGMA user_version = 3');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await LedgerStore(upgraded).openingBalance(id), 100);
    final pulled = LedgerSync(upgraded, (_, _, _) async {
      return pull(
        transactions: [
          {...tx('a'), 'importedId': 'pdfimport-x'},
          {...tx('b'), 'importedId': 'pdfimport-x'},
        ],
      );
    });
    expect((await pulled.pull(budget)).transactions, 2);
    final indexes = await upgraded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'ledger_transactions'")
        .get();
    expect(
      {for (final r in indexes) r.read<String>('name')},
      containsAll([
        'ledger_transactions_account_date',
        'ledger_transactions_scope_date',
        'ledger_transactions_account_imported',
      ]),
    );
  });
}
