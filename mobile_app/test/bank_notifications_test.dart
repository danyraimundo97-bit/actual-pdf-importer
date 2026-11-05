import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/ledger_store.dart';
import 'package:mobile_app/data/models/quick_add.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/bank_notifications/bank_notifications.dart';
import 'package:mobile_app/features/bank_notifications/screens/bank_notifications_screen.dart';
import 'package:mobile_app/features/bank_notifications/widgets/bank_notification_sheet.dart';

class _FakeChannel extends BankNotificationsChannel {
  final removed = <String>[];

  @override
  bool get available => true;

  @override
  Future<Set<String>> trackedApps() async => {'pt.bank.moey'};

  @override
  Future<List<({String package, String label})>> installedApps() async => [
    (package: 'pt.bank.moey', label: 'Moey app'),
    (package: 'com.game', label: 'A game'),
  ];

  @override
  Future<void> remove(String id) async => removed.add(id);
}

void main() {
  testWidgets('choosing apps: search, tick, and Done returns them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Set<String>? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () async {
              chosen = await showModalBottomSheet<Set<String>>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ChooseAppsSheet(
                  apps: [
                    (package: 'pt.bank.moey', label: 'Moey'),
                    (package: 'pt.bank.activo', label: 'ActivoBank'),
                    (package: 'com.game', label: 'A game'),
                  ],
                  selected: {'pt.bank.activo'},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'moe');
    await tester.pump();
    expect(find.text('A game'), findsNothing);
    await tester.tap(find.text('Moey'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(chosen, {'pt.bank.activo', 'pt.bank.moey'});
  });

  test('another app, with no rules of its own, still gets the amount read', () {
    expect(parseBankNotification('other', 'Compra', 'Pagaste 12,50 €'), (amountCents: 1250, income: null));
  });

  group('parseBankNotification', () {
    test('the notifications the banks really send', () {
      expect(
        parseBankNotification(
          'activobank',
          'Transferencia recebida',
          'Recebeu uma transferencia no valor de 0,01 euros para a conta 123456',
        ),
        (amountCents: 1, income: true),
      );
      expect(parseBankNotification('activobank', 'Enviou 0,01 EUR', 'da conta 123456'), (
        amountCents: 1,
        income: false,
      ));
      expect(parseBankNotification('moey', 'Moey', 'Acabaste de receber 0,01€'), (amountCents: 1, income: true));
    });

    test('other amounts: thousands, whole euros, and an account number is not one', () {
      expect(parseBankNotification('activobank', 'Enviou 1.234,56 EUR', 'da conta 999').amountCents, 123456);
      expect(parseBankNotification('moey', 'Moey', 'Acabaste de receber 12€').amountCents, 1200);
      expect(parseBankNotification('activobank', 'Aviso', 'Conta 123456 atualizada').amountCents, isNull);
    });

    test('what it cannot tell stays empty, for the pop-up to ask', () {
      expect(parseBankNotification('mbway', 'MB WAY', 'Pagamento de 5,00 €'), (amountCents: 500, income: null));
      expect(parseBankNotification('moey', 'Moey', 'Novidades na app'), (amountCents: null, income: null));
    });
  });

  test('matchingPayees ignores case and accents, and puts names starting with it first', () {
    const payees = [
      RecentPayee(name: 'Super Farmácia'),
      RecentPayee(name: 'Farmácia Central'),
      RecentPayee(name: 'Lidl'),
    ];
    expect(matchingPayees(payees, 'FARMA').map((p) => p.name), ['Farmácia Central', 'Super Farmácia']);
    expect(matchingPayees(payees, ''), isEmpty);
    expect(matchingPayees(payees, 'zzz'), isEmpty);
  });

  group('the pop-up', () {
    late AppDatabase db;
    late LedgerStore store;
    late _FakeChannel channel;
    late String account;
    const groceries = 'preset:food.groceries';
    final moey = BankNotification(
      id: 'abc-123',
      bank: 'moey',
      title: 'Moey',
      text: 'Acabaste de receber 0,01€',
      postedAt: DateTime(2026, 11, 5, 10),
    );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = LedgerStore(db);
      channel = _FakeChannel();
    });
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    Future<void> pump(WidgetTester tester, BankNotification notification) async {
      await tester.runAsync(() async {
        account = await store.createAccount(phoneScope, name: 'Moey', bankId: 'moey');
        await store.createAccount(phoneScope, name: 'Other');
        await store.addTransactions(account, [
          LedgerDraft(date: DateTime(2026, 10, 1), amountCents: -500, payee: 'Farmácia Central', categoryId: groceries),
        ]);
      });
      SharedPreferences.setMockInitialValues({'onboarded': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            bankNotificationsProvider.overrideWithValue(channel),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: BankNotificationSheet(notification: notification)),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> finishSheet(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    /// The sheet again, on the accounts [pump] made, with a default for the app.
    Future<void> pumpWithDefault(WidgetTester tester, BankNotification notification, String accountId) async {
      SharedPreferences.setMockInitialValues({'notification_account_pt.bank.moey': accountId});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            bankNotificationsProvider.overrideWithValue(channel),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: BankNotificationSheet(notification: notification)),
          ),
        ),
      );
      await settle(tester);
    }

    Future<LedgerTransaction> saved(WidgetTester tester) async => (await tester.runAsync(
      () async => (await store.transactions(account)).firstWhere((t) => t.importedId == 'app-abc-123'),
    ))!;

    Finder payeeField() => find.byKey(const ValueKey('bank-notification-payee'));
    Finder amountField() => find.byKey(const ValueKey('bank-notification-amount'));

    testWidgets('fills what the bank said, and picking a suggested payee fills its category', (tester) async {
      await pump(tester, moey);
      expect(tester.widget<TextField>(amountField()).controller!.text, '0,01');

      await tester.enterText(payeeField(), 'farma');
      await settle(tester);
      await tester.tap(find.text('Farmácia Central'));
      await settle(tester);
      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);

      final row = await saved(tester);
      expect((row.amountCents, row.categoryId, row.date), (1, groceries, '2026-11-05'));
      expect(channel.removed, ['abc-123']);
    });

    testWidgets('a new payee gets mapped from the transaction', (tester) async {
      await pump(tester, moey);
      await tester.enterText(payeeField(), 'Novo Café');
      await settle(tester);
      await tester.tap(find.text('No category'));
      await settle(tester);
      await tester.tap(find.text('Groceries'));
      await settle(tester);
      expect(find.textContaining('will go to Groceries next time'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect((await saved(tester)).categoryId, groceries);
      final mapped = await tester.runAsync(() => db.select(db.payeeCategories).get());
      expect(mapped!.map((m) => m.categoryId), contains(groceries));
    });

    testWidgets('the amount can be typed or corrected; without one it cannot save', (tester) async {
      await pump(
        tester,
        BankNotification(
          id: 'abc-123',
          bank: 'mbway',
          title: 'MB WAY',
          text: 'Pagamento',
          postedAt: DateTime(2026, 11, 5),
        ),
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(channel.removed, isEmpty);

      await tester.enterText(amountField(), '12,50');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await saved(tester)).amountCents, -1250, reason: 'an expense unless it says otherwise');
    });

    testWidgets('Not counted has no other account to name', (tester) async {
      await pump(tester, moey);
      await tester.tap(find.text('No category'));
      await settle(tester);
      await tester.ensureVisible(find.text('Not counted'));
      await tester.pump();
      await tester.tap(find.text('Not counted'));
      await settle(tester);
      expect(find.text('Came from (optional)'), findsNothing);
    });

    testWidgets('moving money between accounts can name the other one, optionally', (tester) async {
      await pump(tester, moey);
      expect(find.text('Came from (optional)'), findsNothing);
      await tester.tap(find.text('No category'));
      await settle(tester);
      await tester.ensureVisible(find.text('Between my accounts'));
      await tester.pump();
      await tester.tap(find.text('Between my accounts'));
      await settle(tester);
      expect(find.text('Came from (optional)'), findsOneWidget, reason: 'it says money came in');

      await tester.tap(find.text('Not set'));
      await settle(tester);
      await tester.tap(find.text('Other').last);
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await saved(tester)).notes, 'From: Other');
      final accounts = await tester.runAsync(() => store.watchAccounts(phoneScope).first);
      final other = accounts!.firstWhere((v) => v.account.name == 'Other');
      expect(other.balanceCents, -1, reason: 'the money left there');
    });

    testWidgets('leaving the other account empty saves without a note', (tester) async {
      await pump(tester, moey);
      await tester.tap(find.text('No category'));
      await settle(tester);
      await tester.ensureVisible(find.text('Between my accounts'));
      await tester.pump();
      await tester.tap(find.text('Between my accounts'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final row = await saved(tester);
      expect(row.notes, isNull);
      expect(row.categoryId, 'preset:money.between_accounts');
    });

    testWidgets('a transaction already there is asked about, and "same" adds nothing', (tester) async {
      await pump(tester, moey);
      await tester.runAsync(
        () => store.addTransactions(account, [
          LedgerDraft(date: moey.postedAt, amountCents: 1, payee: 'From the other bank', importedId: 'app-other'),
        ]),
      );
      await tester.enterText(amountField(), '0,01');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.text('Is this already saved?'), findsOneWidget);
      expect(find.textContaining('From the other bank'), findsOneWidget);
      await tester.tap(find.text('Same, skip it'));
      await settle(tester);

      final rows = await tester.runAsync(() => store.transactions(account));
      expect(rows!.where((t) => t.importedId == 'app-abc-123'), isEmpty);
      expect(channel.removed, ['abc-123']);
    });

    testWidgets('the default account set for an app wins, and one from elsewhere is ignored', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notification = BankNotification(
        id: 'abc-123',
        package: 'pt.bank.moey',
        bank: 'moey',
        title: 'Moey',
        text: 'Acabaste de receber 1,00€',
        postedAt: DateTime(2026, 11, 5),
      );
      await pump(tester, notification);
      Finder picked(String name) =>
          find.descendant(of: find.byType(DropdownButtonFormField<String>), matching: find.text(name));
      expect(picked('Moey'), findsOneWidget, reason: 'nothing set: the bank\'s account');
      await finishSheet(tester);

      final other = (await tester.runAsync(() async {
        return (await store.accounts(phoneScope)).firstWhere((a) => a.name == 'Other').id;
      }))!;
      await pumpWithDefault(tester, notification, other);
      expect(picked('Other'), findsOneWidget);
      await finishSheet(tester);

      await pumpWithDefault(tester, notification, 'gone');
      expect(picked('Moey'), findsOneWidget);
    });

    testWidgets('the settings screen sets an app\'s default account', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(() => store.createAccount(phoneScope, name: 'Savings'));
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            bankNotificationsProvider.overrideWithValue(channel),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const BankNotificationsScreen()),
        ),
      );
      await settle(tester);

      expect(find.text('Starts on: Automatic'), findsOneWidget);
      expect(find.text('A game'), findsNothing, reason: 'not tracked');
      await tester.tap(find.text('Starts on: Automatic'));
      await settle(tester);
      await tester.tap(find.text('Savings'));
      await settle(tester);
      expect(find.text('Starts on: Savings'), findsOneWidget);
      expect(prefs.getString('notification_account_pt.bank.moey'), isNotNull);
    });

    testWidgets('it goes to the bank\'s own account; "Not a transaction" adds nothing', (tester) async {
      await pump(tester, moey);
      expect(find.text('Moey'), findsWidgets);
      await tester.tap(find.text('Not a transaction'));
      await settle(tester);
      expect(channel.removed, ['abc-123']);
      final rows = await tester.runAsync(() => store.transactions(account));
      expect(rows!.where((t) => t.importedId == 'app-abc-123'), isEmpty);
    });
  });
}
