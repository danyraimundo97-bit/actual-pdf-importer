import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/secret_store.dart';
import 'package:mobile_app/data/models/actual_account.dart';
import 'package:mobile_app/data/models/actual_category.dart';
import 'package:mobile_app/data/models/budget_month.dart';
import 'package:mobile_app/data/models/quick_add.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/quick_add/quick_add_controller.dart';
import 'package:mobile_app/features/quick_add/screens/quick_add_screen.dart';

const _options = QuickAddOptions(
  accounts: [
    ActualAccount(id: 'chk', name: 'Checking', offbudget: false, closed: false),
    ActualAccount(id: 'cash', name: 'Cash', offbudget: false, closed: false),
  ],
  categoryGroups: [
    ActualCategoryGroup(id: 'food', name: 'Food', categories: [ActualCategory(id: 'groc', name: 'Groceries')]),
    ActualCategoryGroup(id: 'inc', name: 'Income', categories: [ActualCategory(id: 'sal', name: 'Salary')]),
  ],
  incomeGroupIds: {'inc'},
  recentPayees: [RecentPayee(name: 'Lidl', lastCategoryId: 'groc'), RecentPayee(name: 'Café')],
);

class _FakeApi implements ImporterApi {
  final calls = <Map<String, Object?>>[];

  /// Fail the next N saves (a dropped connection).
  int failures = 0;

  @override
  Future<QuickAddOptions> getQuickAddOptions({String? budgetSyncId}) async => _options;

  @override
  Future<({String? id, bool created})> addTransaction({
    required String accountId,
    required DateTime date,
    required int amountCents,
    required String clientId,
    String? payeeName,
    String? categoryId,
    String? notes,
    String? budgetSyncId,
    String? budgetPassword,
  }) async {
    calls.add({
      'accountId': accountId,
      'amountCents': amountCents,
      'clientId': clientId,
      'payeeName': payeeName,
      'categoryId': categoryId,
    });
    if (failures > 0) {
      failures--;
      throw const ApiException(message: 'Could not reach the importer backend.');
    }
    return (id: 'tx-1', created: calls.length == 1);
  }

  @override
  Future<BudgetMonth> getBudgetMonth({String? budgetSyncId, String? month}) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecrets implements SecretStore {
  @override
  Future<String?> budgetPassword(String syncId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ProviderContainer, _FakeApi, SharedPreferences)> _container({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'budget_sync_id': 'casa', ...prefs});
  final sp = await SharedPreferences.getInstance();
  final api = _FakeApi();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      importerApiProvider.overrideWithValue(api),
      secretStoreProvider.overrideWithValue(_FakeSecrets()),
    ],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose controller alive for the whole test.
  container.listen(quickAddControllerProvider, (_, _) {});
  return (container, api, sp);
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

  test('a failed save keeps the form, and the retry reuses the same clientId', () async {
    final (c, api, sp) = await _container();
    final controller = c.read(quickAddControllerProvider.notifier)..applyOptions(_options);
    controller.setAmount('4,50');
    controller.setPayee('Café', options: _options);
    api.failures = 1;

    expect(await controller.save(), isFalse);
    expect(c.read(quickAddControllerProvider).error, isNotNull);
    expect(c.read(quickAddControllerProvider).amountText, '4,50');

    expect(await controller.save(), isTrue);
    expect(api.calls, hasLength(2));
    expect(api.calls[0]['clientId'], api.calls[1]['clientId']);
    expect(api.calls[1]['amountCents'], -450);
    expect(api.calls[1]['payeeName'], 'Café');
    expect(sp.getString('last_account_id'), 'chk');
  });

  testWidgets('type an amount, pick a known payee, save', (tester) async {
    SharedPreferences.setMockInitialValues({'budget_sync_id': 'casa', 'backend_url': 'http://b'});
    final sp = await SharedPreferences.getInstance();
    final api = _FakeApi();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          importerApiProvider.overrideWithValue(api),
          secretStoreProvider.overrideWithValue(_FakeSecrets()),
          linkStateProvider.overrideWith((ref) async => LinkState.ready),
        ],
        child: const MaterialApp(home: QuickAddScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '12,30');
    await tester.enterText(find.byType(TextField).at(1), 'Lid');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lidl').last);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.calls.single, {
      'accountId': 'chk',
      'amountCents': -1230,
      'clientId': api.calls.single['clientId'],
      'payeeName': 'Lidl',
      'categoryId': 'groc',
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
