import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/import_history_store.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/models/actual_account.dart';
import 'package:mobile_app/data/models/import_result.dart';
import 'package:mobile_app/data/models/parse_result.dart';
import 'package:mobile_app/data/models/parsed_transaction.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/review/phone_save.dart';
import 'package:mobile_app/features/review/screens/review_screen.dart';
import 'package:mobile_app/features/review/screens/review_screen_args.dart';

// docs/plans/local-ledger.md, Phase 3: saving a reviewed statement on the
// phone when Actual isn't connected.

ParsedTransaction tx(String payee, int cents, String importedId, {String? category}) => ParsedTransaction(
  date: DateTime(2026, 10, 3),
  payee: payee,
  amountCents: cents,
  rawLine: '',
  importedId: importedId,
  suggestedCategoryId: category,
  suggestedCategoryName: category,
);

LedgerAccount account(String id, {String? bankId}) => LedgerAccount(
  id: id,
  scope: phoneScope,
  name: id,
  offBudget: false,
  closed: false,
  sort: 0,
  bankId: bankId,
  updatedAt: 0,
  deleted: false,
);

void main() {
  group('suggested account', () {
    final checking = account('checking', bankId: 'moey');
    final card = account('card');

    test('the last one used for the bank, then one set up for it, then the only one', () {
      expect(suggestLedgerAccount([checking, card], bankId: 'moey', lastUsedId: 'card'), card);
      expect(suggestLedgerAccount([checking, card], bankId: 'moey'), checking);
      expect(suggestLedgerAccount([card], bankId: 'moey'), card);
    });

    test('no guess when there is a real choice, or nothing to choose', () {
      expect(suggestLedgerAccount([checking, card], bankId: 'cgd'), isNull);
      expect(suggestLedgerAccount([], bankId: 'moey'), isNull);
      // A closed account isn't offered, even if it was the last one used.
      expect(suggestLedgerAccount([checking, card], bankId: 'cgd', lastUsedId: 'gone'), isNull);
    });
  });

  test('drafts keep the importedId and the chosen category', () {
    final edited = tx(
      'SHOP',
      -1230,
      'pdfimport-a',
      category: 'preset:groceries',
    ).copyWith(payee: 'Market', amountCents: -1500, overrideCategoryId: 'local:home', overrideCategoryName: 'Home');
    final [draft] = statementDrafts([edited]);
    expect(
      (draft.payee, draft.amountCents, draft.importedId, draft.categoryId),
      ('Market', -1500, 'pdfimport-a', 'local:home'),
    );
  });

  test('a history entry remembers it was saved on the phone', () {
    final entry = ImportHistoryEntry(
      filename: 'october.pdf',
      bankId: 'moey',
      accountName: 'Checking',
      added: 2,
      updated: 0,
      at: DateTime(2026, 11, 4),
      accountId: 'acct:1',
      addedIds: const ['tx:1', 'tx:2'],
      onPhone: true,
    );
    final back = ImportHistoryEntry.fromJson(entry.toJson());
    expect((back.onPhone, back.canUndo), (true, true));
    expect(ImportHistoryEntry.fromJson({...entry.toJson()}..remove('onPhone')).onPhone, isFalse);
  });

  group('Review', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    /// Review pushed over a home page that keeps what it popped with.
    Future<List<ImportResult?>> pumpReview(
      WidgetTester tester,
      List<ParsedTransaction> lines, {
      ActualAccount? actualAccount,
      String? budgetSyncId,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final popped = <ImportResult?>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async => popped.add(
                  await context.push<ImportResult>(
                    '/review',
                    extra: ReviewScreenArgs(
                      parseResult: ParseResult(bankId: 'moey', transactions: lines),
                      account: actualAccount,
                      budgetSyncId: budgetSyncId,
                      saveOnPhone: actualAccount == null,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          GoRoute(
            path: '/review',
            builder: (_, state) => ReviewScreen(args: state.extra! as ReviewScreenArgs),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs), appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      return popped;
    }

    testWidgets('saves into the only account; the same statement again adds nothing', (tester) async {
      final store = LedgerStore(db);
      final id = (await tester.runAsync(() => store.createAccount(phoneScope, name: 'Checking')))!;
      final lines = [tx('SHOP', -1230, 'pdfimport-a'), tx('CAFE', -250, 'pdfimport-b')];

      var popped = await pumpReview(tester, lines);
      expect(find.text('Checking'), findsOneWidget);
      expect(find.textContaining('Connect Actual to import'), findsNothing);
      await tester.tap(find.text('Save 2 transactions'));
      await settle(tester);
      expect(find.text('Saved on this phone'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      final [result] = popped;
      expect((result!.added, result.updated, result.phoneAccount?.id), (2, 0, id));
      final saved = (await tester.runAsync(() => store.transactions(id)))!;
      expect({for (final t in saved) t.importedId}, {'pdfimport-a', 'pdfimport-b'});
      expect((await tester.runAsync(() => store.account(id)))!.bankId, 'moey');
      await finish(tester);

      popped = await pumpReview(tester, lines);
      await tester.tap(find.text('Save 2 transactions'));
      await settle(tester);
      expect(find.text('Already on the phone'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect((popped.single!.added, popped.single!.updated), (0, 2));
      await finish(tester);
    });

    testWidgets('importing into Actual writes to its copy first, with the lines; undoing goes through the ledger', (
      tester,
    ) async {
      const budget = 'budget-1';
      final store = LedgerStore(db);
      await tester.runAsync(() async {
        await db
            .into(db.ledgerAccounts)
            .insert(LedgerAccountsCompanion.insert(id: 'chk', scope: budget, name: 'Checking', sort: 0, updatedAt: 0));
        await db.into(db.ledgerSyncState).insert(LedgerSyncStateCompanion.insert(scope: budget, lastPulledAt: const Value(1)));
      });
      final line = ParsedTransaction(
        date: DateTime(2026, 10, 3),
        payee: 'SHOP',
        amountCents: -1230,
        rawLine: 'line from the statement',
        importedId: 'pdfimport-a',
      );

      final popped = await pumpReview(
        tester,
        [line],
        actualAccount: const ActualAccount(id: 'chk', name: 'Checking', offbudget: false, closed: false),
        budgetSyncId: budget,
      );
      await tester.tap(find.text('Import 1 transaction'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await settle(tester);
      expect(find.text('Import complete'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      final result = popped.single!;
      expect((result.added, result.onPhone, result.inLedger), (1, false, true));
      final row = (await tester.runAsync(() => store.transaction(result.addedIds.single)))!;
      expect((row.scope, row.accountId, row.notes, row.importedId), (budget, 'chk', 'line from the statement', 'pdfimport-a'));
      expect((await tester.runAsync(() => store.watchOutboxSummary(budget).first))!.waiting, 2);

      final removed = (await tester.runAsync(() => store.deleteTransactions(result.addedIds)))!;
      expect(removed.removed, 1);
      await finish(tester);
    });

    group('a line with the same date and amount as a saved transaction', () {
      Future<(LedgerStore, String)> seeded(WidgetTester tester) async {
        final store = LedgerStore(db);
        final id = (await tester.runAsync(() async {
          final id = await store.createAccount(phoneScope, name: 'Checking');
          await store.addTransactions(id, [
            LedgerDraft(date: DateTime(2026, 10, 3), amountCents: -1230, payee: 'Quick coffee', importedId: 'app-1'),
          ]);
          return id;
        }))!;
        return (store, id);
      }

      Future<Set<String?>> ids(WidgetTester tester, LedgerStore store, String account) async => {
        for (final t in (await tester.runAsync(() => store.transactions(account)))!) t.importedId,
      };

      final lines = [tx('SHOP', -1230, 'pdfimport-a'), tx('CAFE', -250, 'pdfimport-b')];

      testWidgets('asks; "same" skips that line and saves the rest', (tester) async {
        final (store, id) = await seeded(tester);
        final popped = await pumpReview(tester, lines);
        await tester.tap(find.text('Save 2 transactions'));
        await settle(tester);

        expect(find.text('Is this already saved?'), findsOneWidget);
        expect(find.textContaining('Quick coffee'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await settle(tester);
        await tester.tap(find.text('Done'));
        await settle(tester);

        expect(await ids(tester, store, id), {'app-1', 'pdfimport-b'});
        expect((popped.single!.added, popped.single!.updated), (1, 1));
        await finish(tester);
      });

      testWidgets('"different" adds it too', (tester) async {
        final (store, id) = await seeded(tester);
        await pumpReview(tester, lines);
        await tester.tap(find.text('Save 2 transactions'));
        await settle(tester);
        await tester.tap(find.text('Different, add it'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await settle(tester);

        expect(await ids(tester, store, id), {'app-1', 'pdfimport-a', 'pdfimport-b'});
        await finish(tester);
      });

      testWidgets('Cancel saves nothing and stays on the review', (tester) async {
        final (store, id) = await seeded(tester);
        final popped = await pumpReview(tester, lines);
        await tester.tap(find.text('Save 2 transactions'));
        await settle(tester);
        await tester.tap(find.text('Cancel'));
        await settle(tester);

        expect(await ids(tester, store, id), {'app-1'});
        expect(popped, isEmpty);
        expect(find.text('Save 2 transactions'), findsOneWidget);
        await finish(tester);
      });

      testWidgets('importing into Actual asks too', (tester) async {
        const budget = 'budget-1';
        final store = LedgerStore(db);
        await tester.runAsync(() async {
          await db
              .into(db.ledgerAccounts)
              .insert(LedgerAccountsCompanion.insert(id: 'chk', scope: budget, name: 'Checking', sort: 0, updatedAt: 0));
          await db
              .into(db.ledgerSyncState)
              .insert(LedgerSyncStateCompanion.insert(scope: budget, lastPulledAt: const Value(1)));
          await store.addTransactions('chk', [
            LedgerDraft(date: DateTime(2026, 10, 3), amountCents: -1230, payee: 'From a notification', importedId: 'app-1'),
          ]);
        });
        await pumpReview(
          tester,
          [tx('SHOP', -1230, 'pdfimport-a')],
          actualAccount: const ActualAccount(id: 'chk', name: 'Checking', offbudget: false, closed: false),
          budgetSyncId: budget,
        );
        await tester.tap(find.text('Import 1 transaction'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Import'));
        await settle(tester);

        expect(find.text('Is this already saved?'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await settle(tester);
        expect(await ids(tester, store, 'chk'), {'app-1'});
        await finish(tester);
      });
    });

    testWidgets('with no account yet, one is added from the picker', (tester) async {
      await pumpReview(tester, [tx('SHOP', -1230, 'pdfimport-a')]);
      expect(find.text('Choose an account to save into'), findsOneWidget);

      await tester.tap(find.text('Choose an account'));
      await settle(tester);
      await tester.tap(find.text('New account…'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Moey');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      expect(find.text('Save 1 transaction'), findsOneWidget);
      final [account] = (await tester.runAsync(() => db.select(db.ledgerAccounts).get()))!;
      expect((account.name, account.bankId), ('Moey', 'moey'));
      await finish(tester);
    });
  });
}
