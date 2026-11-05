import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/secret_store.dart';
import 'package:mobile_app/data/models/actual_budget.dart';
import 'package:mobile_app/data/models/actual_connection.dart';
import 'package:mobile_app/data/models/backend_config.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/setup/screens/setup_screen.dart';

/// A backend with an optional Actual server.
class _FakeImporterApi implements ImporterApi {
  HealthStatus status = HealthStatus.ok;
  bool actualConfigured = false;
  bool actualLocked = false;

  /// When set, connecting to Actual fails with this backend error code.
  String? connectError;
  String? connectedUrl;

  @override
  Future<HealthStatus> health() async => status;

  @override
  Future<BackendConfig> getConfig() async => BackendConfig(
        parserMode: 'regex',
        aiConfigured: false,
        actualConfigured: actualConfigured,
        actualLocked: actualLocked,
      );

  @override
  Future<ActualConnection> getActualConnection() async => ActualConnection(
        configured: actualConfigured,
        locked: actualLocked,
        serverUrl: actualConfigured ? 'http://actual.lan:5006' : null,
      );

  @override
  Future<ActualConnection> connectActual({required String serverUrl, required String password}) async {
    if (connectError != null) {
      throw ApiException(statusCode: 401, message: 'nope', code: connectError);
    }
    actualConfigured = true;
    connectedUrl = serverUrl;
    return ActualConnection(configured: true, locked: false, serverUrl: serverUrl, serverVersion: '26.10.0');
  }

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

  Future<void> pumpSetup(WidgetTester tester, {int step = 0}) async {
    // Tall enough that the whole last page fits without scrolling.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = _FakeImporterApi();
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, _) => SetupScreen(initialStep: step)),
        GoRoute(path: '/dashboard', builder: (_, _) => const Text('DASHBOARD')),
        GoRoute(path: '/import', builder: (_, _) => const Text('IMPORT')),
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

  Future<void> connectBackend(WidgetTester tester, String url) async {
    await tester.tap(find.text('Connect Actual'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), url);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Not now" finishes the guide without connecting and lands on Import', (tester) async {
    await pumpSetup(tester);
    expect(find.text('How it works'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your budget'), findsOneWidget);
    expect(find.text('Envelopes'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Bring your budget along'), findsOneWidget);
    expect(find.text('With Actual'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('IMPORT'), findsOneWidget);
    expect(prefs.getBool('onboarded'), isTrue);
    expect(prefs.getString('budget_sync_id'), isNull);
  });

  testWidgets('connects the backend, then Actual, picks a budget and finishes on Home', (tester) async {
    await pumpSetup(tester, step: SetupScreen.lastStep);
    expect(find.text('Finish'), findsNothing, reason: 'collapsed until "Connect Actual"');

    await connectBackend(tester, 'http://10.0.0.2:3000');
    expect(find.text('Your Actual server'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'http://actual.lan:5006');
    await tester.enterText(find.byType(TextField).at(3), 'secret');
    await tester.tap(find.text('Test & connect'));
    await tester.pumpAndSettle();
    expect(api.connectedUrl, 'http://actual.lan:5006');
    expect(find.text('Connected to Actual 26.10.0.'), findsOneWidget);

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(prefs.getBool('onboarded'), isTrue);
    expect(prefs.getString('budget_sync_id'), 'casa');
    expect(prefs.getString('backend_url'), 'http://10.0.0.2:3000');
  });

  testWidgets('a rejected Actual password is explained inline, and the form stays', (tester) async {
    await pumpSetup(tester, step: SetupScreen.lastStep);
    await connectBackend(tester, 'http://10.0.0.2:3000');
    api.connectError = 'ACTUAL_AUTH_FAILED';

    await tester.enterText(find.byType(TextField).at(2), 'http://actual.lan:5006');
    await tester.tap(find.text('Test & connect'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Actual rejected the password'), findsOneWidget);
    expect(find.text('Test & connect'), findsOneWidget);
    expect(find.text('Casa'), findsNothing);
  });

  testWidgets("a backend without IMPORT_TOKEN says why it can't be changed", (tester) async {
    await pumpSetup(tester, step: SetupScreen.lastStep);
    await connectBackend(tester, 'http://10.0.0.2:3000');
    api.connectError = 'AUTH_REQUIRED';

    await tester.enterText(find.byType(TextField).at(2), 'http://actual.lan:5006');
    await tester.tap(find.text('Test & connect'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Set IMPORT_TOKEN'), findsOneWidget);
  });

  testWidgets('a server set in the backend .env is shown read-only, straight to the budgets', (tester) async {
    await pumpSetup(tester, step: SetupScreen.lastStep);
    api
      ..actualConfigured = true
      ..actualLocked = true;
    await connectBackend(tester, 'http://10.0.0.2:3000');

    expect(find.text('Test & connect'), findsNothing);
    expect(find.textContaining("Set in the backend's .env"), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
  });

  testWidgets('an unreachable backend keeps you on the page with an error', (tester) async {
    await pumpSetup(tester, step: SetupScreen.lastStep);
    api.status = HealthStatus.unreachable;
    await connectBackend(tester, 'http://10.0.0.9:3000');

    expect(find.textContaining('Could not reach the importer'), findsOneWidget);
    expect(find.text('Your Actual server'), findsNothing);
  });

  testWidgets('a URL that answers but is not the backend (e.g. Actual) says so', (tester) async {
    await pumpSetup(tester, step: SetupScreen.lastStep);
    api.status = HealthStatus.notImporter;
    await connectBackend(tester, 'http://10.0.0.9:5006');

    expect(find.textContaining('it is not the importer backend'), findsOneWidget);
  });
}
