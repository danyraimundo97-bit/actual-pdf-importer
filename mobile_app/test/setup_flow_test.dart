import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/secret_store.dart';
import 'package:mobile_app/data/models/actual_budget.dart';
import 'package:mobile_app/data/models/backend_config.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/setup/screens/setup_screen.dart';

class _FakeImporterApi implements ImporterApi {
  bool healthy = true;

  @override
  Future<bool> health() async => healthy;

  @override
  Future<BackendConfig> getConfig() async =>
      const BackendConfig(parserMode: 'regex', aiConfigured: false);

  @override
  Future<List<ActualBudget>> getBudgets() async => const [
    ActualBudget(syncId: 'casa', name: 'Casa', encrypted: false),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecretStore implements SecretStore {
  String? token;

  @override
  Future<String?> get apiToken async => token;

  @override
  Future<void> setApiToken(String value) async => token = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late _FakeImporterApi api;

  Future<void> pumpSetup(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = _FakeImporterApi();
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
        GoRoute(path: '/dashboard', builder: (_, _) => const Text('DASHBOARD')),
        GoRoute(path: '/welcome', builder: (_, _) => const Text('WELCOME')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          importerApiProvider.overrideWithValue(api),
          secretStoreProvider.overrideWithValue(_FakeSecretStore()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('walks from connect to the dashboard and marks onboarding done', (tester) async {
    await pumpSetup(tester);
    expect(find.text('Connect to your importer'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'http://10.0.0.2:3000');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connection works'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a budget'), findsOneWidget);

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("You're all set"), findsOneWidget);

    await tester.tap(find.text('Open dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(prefs.getBool('onboarded'), isTrue);
    expect(prefs.getString('budget_sync_id'), 'casa');
    expect(prefs.getString('backend_url'), 'http://10.0.0.2:3000');
  });

  testWidgets('an unreachable importer keeps you on the connect step with an error', (
    tester,
  ) async {
    await pumpSetup(tester);
    api.healthy = false;

    await tester.enterText(find.byType(TextField).first, 'http://10.0.0.9:3000');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Connect to your importer'), findsOneWidget);
    expect(find.textContaining('Could not reach the importer'), findsOneWidget);
  });
}
