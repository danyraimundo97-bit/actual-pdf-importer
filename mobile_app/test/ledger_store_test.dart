import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:sqlite3/sqlite3.dart';

// docs/plans/local-ledger.md, Phase 2.

void main() {
  late AppDatabase db;
  late LedgerStore store;
  var clock = DateTime(2026, 11, 4, 12);

  setUp(() {
    clock = DateTime(2026, 11, 4, 12);
    db = AppDatabase(NativeDatabase.memory());
    store = LedgerStore(db, now: () => clock);
  });
  tearDown(() => db.close());

  Future<List<LedgerAccountView>> accounts() => store.watchAccounts(phoneScope).first;

  LedgerDraft draft(String date, int cents, {String? payee, String? importedId, String? categoryId}) => LedgerDraft(
    date: DateTime.parse(date),
    amountCents: cents,
    payee: payee,
    importedId: importedId,
    categoryId: categoryId,
  );

  group('accounts', () {
    test('a new account with an opening balance shows it as its balance', () async {
      final id = await store.createAccount(phoneScope, name: ' Checking ', openingBalanceCents: 125000);
      final [view] = await accounts();
      expect(view.account.id, id);
      expect(view.account.name, 'Checking');
      expect(view.balanceCents, 125000);
      expect(await store.openingBalance(id), 125000);

      final [opening] = await store.transactions(id);
      expect(opening.startingBalance, isTrue);
      expect(opening.date, '2026-11-04');
    });

    test('balances add every live transaction, and accounts keep their order with closed ones last', () async {
      final card = await store.createAccount(phoneScope, name: 'Card');
      final savings = await store.createAccount(phoneScope, name: 'Savings', offBudget: true, openingBalanceCents: 500);
      final checking = await store.createAccount(phoneScope, name: 'Checking');
      await store.addTransactions(card, [draft('2026-11-01', -1250), draft('2026-11-02', -750)]);
      final gone = await store.addTransaction(card, draft('2026-11-03', -9999));
      await store.deleteTransaction(gone!);
      await store.updateAccount(savings, closed: true);
      await store.reorderAccounts(phoneScope, [checking, card, savings]);

      final list = await accounts();
      expect([for (final v in list) v.account.name], ['Checking', 'Card', 'Savings']);
      expect([for (final v in list) v.balanceCents], [0, -2000, 500]);
      expect(list.last.account.closed, isTrue);
      expect(list.last.account.offBudget, isTrue);
    });

    test('the opening balance can be changed and removed', () async {
      final id = await store.createAccount(phoneScope, name: 'Checking');
      await store.setOpeningBalance(id, -4000);
      expect(await store.openingBalance(id), -4000);
      await store.setOpeningBalance(id, 2500);
      expect(await store.openingBalance(id), 2500);
      expect((await store.transactions(id)).length, 1);
      await store.setOpeningBalance(id, 0);
      expect(await store.openingBalance(id), 0);
      expect(await store.transactions(id), isEmpty);
    });

    test('scopes do not mix', () async {
      await store.createAccount(phoneScope, name: 'Phone');
      await store.createAccount('budget-1', name: 'Actual');
      expect([for (final v in await accounts()) v.account.name], ['Phone']);
    });
  });

  group('transactions', () {
    test('the same statement twice adds nothing the second time', () async {
      final id = await store.createAccount(phoneScope, name: 'Checking');
      final statement = [
        draft('2026-10-01', -450, payee: 'Bakery', importedId: 'pdfimport-a'),
        draft('2026-10-01', -450, payee: 'Bakery', importedId: 'pdfimport-a-1'),
        draft('2026-10-02', 120000, payee: 'Employer', importedId: 'pdfimport-b'),
      ];
      final first = await store.addTransactions(id, statement);
      expect((first.added, first.skipped), (3, 0));
      final second = await store.addTransactions(id, statement);
      expect((second.added, second.skipped), (0, 3));
      expect((await store.transactions(id)).length, 3);
    });

    test('a removed transaction still counts as imported, as in Actual', () async {
      final id = await store.createAccount(phoneScope, name: 'Checking');
      final txId = await store.addTransaction(id, draft('2026-10-01', -450, importedId: 'pdfimport-a'));
      await store.deleteTransaction(txId!);
      expect(await store.addTransaction(id, draft('2026-10-01', -450, importedId: 'pdfimport-a')), isNull);
      expect(await store.transactions(id), isEmpty);
    });

    test('the same importedId may exist in two accounts', () async {
      final a = await store.createAccount(phoneScope, name: 'A');
      final b = await store.createAccount(phoneScope, name: 'B');
      expect(await store.addTransaction(a, draft('2026-10-01', -1, importedId: 'pdfimport-x')), isNotNull);
      expect(await store.addTransaction(b, draft('2026-10-01', -1, importedId: 'pdfimport-x')), isNotNull);
    });

    test('payees are shared by name, ignoring case', () async {
      final id = await store.createAccount(phoneScope, name: 'Checking');
      final ids = (await store.addTransactions(id, [
        draft('2026-10-01', -1, payee: 'Bakery'),
        draft('2026-10-02', -1, payee: ' bakery '),
      ])).ids;
      final rows = [for (final t in ids) (await store.transaction(t))!];
      expect(rows[0].payeeId, isNotNull);
      expect(rows[0].payeeId, rows[1].payeeId);
    });

    test('an edit keeps the importedId; the category can be cleared', () async {
      final id = await store.createAccount(phoneScope, name: 'Checking');
      final txId = await store.addTransaction(
        id,
        draft('2026-10-01', -450, importedId: 'pdfimport-a', categoryId: 'preset:groceries'),
      );
      await store.updateTransaction(txId!, amountCents: -500, notes: 'split with Ana', payee: 'Market');
      var tx = (await store.transaction(txId))!;
      expect(
        (tx.amountCents, tx.notes, tx.importedId, tx.categoryId),
        (-500, 'split with Ana', 'pdfimport-a', 'preset:groceries'),
      );
      await store.updateTransaction(txId, clearCategory: true);
      tx = (await store.transaction(txId))!;
      expect(tx.categoryId, isNull);
    });
  });

  group('budget amounts', () {
    test('set, overwrite and copy from last month', () async {
      await store.setBudget(phoneScope, 'preset:groceries', '2026-10', 30000);
      await store.setBudget(phoneScope, 'preset:groceries', '2026-10', 32000);
      await store.setBudget(phoneScope, 'preset:transport', '2026-10', 5000);
      await store.setBudget(phoneScope, 'preset:transport', '2026-11', 6000);
      expect(await store.copyPreviousMonth(phoneScope, '2026-11'), 1);
      expect(await store.budgets(phoneScope, '2026-11'), {'preset:groceries': 32000, 'preset:transport': 6000});
    });

    test('months are YYYY-MM and January follows December', () {
      expect(previousMonth('2026-01'), '2025-12');
      expect(previousMonth('2026-11'), '2026-10');
      expect(() => store.setBudget(phoneScope, 'c', '2026-13', 1), throwsArgumentError);
    });
  });

  group('outbox', () {
    test('every change queues its row once, in order, and a removal becomes a delete', () async {
      final id = await store.createAccount(phoneScope, name: 'Checking');
      final txId = await store.addTransaction(id, draft('2026-10-01', -450, payee: 'Bakery'));
      await store.updateTransaction(txId!, amountCents: -500);
      await store.updateAccount(id, name: 'Main');
      await store.deleteTransaction(txId);
      await store.setBudget(phoneScope, 'preset:groceries', '2026-10', 30000);

      final queue = await store.outbox(phoneScope);
      expect(
        [for (final o in queue) '${o.kind}:${o.op}'],
        ['account:put', 'payee:put', 'transaction:delete', 'budget:put'],
      );
      expect(queue.last.rowId, 'preset:groceries|2026-10');
      expect(await store.watchOutboxCount(phoneScope).first, 4);
    });
  });

  test('upgrading from schema 2 keeps the categories and adds the ledger', () async {
    final dir = Directory.systemTemp.createTempSync('ledger-migration-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    // A schema 3 file made to look like schema 2: the ledger tables dropped
    // and the version set back.
    final current = AppDatabase(NativeDatabase(file));
    final categories = (await current.select(current.categories).get()).length;
    await current.close();
    final raw = sqlite3.open(file.path);
    for (final table in [
      'ledger_transactions',
      'ledger_accounts',
      'ledger_payees',
      'ledger_budgets',
      'ledger_outbox',
      'ledger_sync_state',
    ]) {
      raw.execute('DROP TABLE $table');
    }
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.select(upgraded.categories).get()).length, categories);
    final ledger = LedgerStore(upgraded);
    final id = await ledger.createAccount(phoneScope, name: 'Checking', openingBalanceCents: 100);
    expect(await ledger.openingBalance(id), 100);
  });
}
