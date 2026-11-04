import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/data/api/importer_api.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/secret_store.dart';
import 'package:mobile_app/data/models/actual_budget.dart';
import 'package:mobile_app/data/models/actual_connection.dart';
import 'package:mobile_app/data/models/backend_config.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/settings/screens/actual_settings_screen.dart';
import 'package:mobile_app/features/settings/screens/backend_settings_screen.dart';
import 'package:mobile_app/features/settings/screens/settings_screen.dart';
import 'package:mobile_app/shared/widgets/settings_group.dart';

class _FakeImporterApi implements ImporterApi {
  HealthStatus status = HealthStatus.ok;
  bool actualConfigured = true;

  @override
  Future<HealthStatus> health() async => status;

  @override
  Future<BackendConfig> getConfig() async =>
      BackendConfig(parserMode: 'regex', aiConfigured: false, actualConfigured: actualConfigured, actualLocked: false);

  @override
  Future<ActualConnection> getActualConnection() async => ActualConnection(
    configured: actualConfigured,
    locked: false,
    serverUrl: actualConfigured ? 'http://actual.lan:5006' : null,
  );

  @override
  Future<List<ActualBudget>> getBudgets() async => const [
    ActualBudget(syncId: 'casa', name: 'Casa', encrypted: false),
    ActualBudget(syncId: 'side', name: 'Side Hustle', encrypted: false),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecretStore implements SecretStore {
  String? token = 'tok';
  int forgotten = 0;

  @override
  Future<String?> get apiToken async => token;

  @override
  Future<void> setApiToken(String value) async => token = value;

  @override
  Future<void> forgetAllPdfPasswords() async => forgotten++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _themed(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('settings widgets', () {
    testWidgets('a row taps; a disabled one does not and is dimmed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _themed(
          SettingsGroup(
            label: 'Group',
            children: [
              SettingsRow(title: 'On', onTap: () => taps++),
              SettingsRow(title: 'Off', enabled: false, onTap: () => taps++),
            ],
          ),
        ),
      );
      await tester.tap(find.text('On'));
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      final dimmed = tester.widget<Opacity>(find.ancestor(of: find.text('Off'), matching: find.byType(Opacity)).first);
      expect(dimmed.opacity, 0.5);
    });

    testWidgets('the whole switch row toggles', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _themed(
          StatefulBuilder(
            builder: (context, setState) => SettingsSwitchRow(
              title: 'Read on this phone',
              subtitle: 'Explained here',
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Explained here'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets("a status is announced as words, with the row's title", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _themed(
          SettingsRow(
            title: 'Backend',
            subtitle: const StatusDot(status: SettingsStatus.ok, label: 'Connected', value: '10.0.0.2'),
            onTap: () {},
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'Backend\s+Connected · 10\.0\.0\.2')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pressing scales the row, except under reduced motion', (tester) async {
      Future<double> pressedScale({required bool reduceMotion}) async {
        await tester.pumpWidget(
          _themed(
            SettingsRow(title: 'Row', onTap: () {}),
            reduceMotion: reduceMotion,
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(find.text('Row')));
        await tester.pumpAndSettle();
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
        await gesture.up();
        await tester.pumpAndSettle();
        return scale;
      }

      expect(await pressedScale(reduceMotion: false), Motion.pressScale);
      expect(await pressedScale(reduceMotion: true), 1);
    });
  });

  group('settings overview', () {
    late _FakeImporterApi api;
    late _FakeSecretStore secrets;
    late SharedPreferences prefs;

    Future<void> pump(
      WidgetTester tester, {
      Map<String, Object> values = const {},
      Size size = const Size(800, 2000),
      double textScale = 1,
      bool dark = false,
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({'onboarded': true, ...values});
      prefs = await SharedPreferences.getInstance();
      api = _FakeImporterApi();
      secrets = _FakeSecretStore();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'backend', builder: (_, _) => const BackendSettingsScreen()),
              GoRoute(path: 'actual', builder: (_, _) => const ActualSettingsScreen()),
              GoRoute(path: 'backups', builder: (_, _) => const Text('BACKUPS')),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            importerApiProvider.overrideWithValue(api),
            secretStoreProvider.overrideWithValue(secrets),
            appDatabaseProvider.overrideWithValue(db),
            // The phone's accounts are a drift stream, which never settles in
            // a widget test; the Accounts screen has its own tests.
            ledgerAccountsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp.router(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const connected = {'backend_url': 'http://10.0.0.2:3000', 'budget_sync_id': 'casa', 'budget_name': 'Casa'};

    testWidgets('without a backend: not set up, Actual waits for it, no budget to pick', (tester) async {
      await pump(tester);
      expect(find.text('Not set up'), findsOneWidget);
      expect(find.text('Needs the backend'), findsOneWidget);
      expect(find.text('Connect Actual first'), findsOneWidget);
      expect(find.text('Match with Actual'), findsNothing);
      expect(find.text('Export and import on this phone'), findsOneWidget);

      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      expect(find.text('Reload budgets'), findsNothing, reason: 'the row is disabled');

      await tester.tap(find.text('Actual'));
      await tester.pumpAndSettle();
      expect(find.text('Connect the backend first'), findsOneWidget);
      await tester.tap(find.text('Set up the backend'));
      await tester.pumpAndSettle();
      expect(find.text('Save and test'), findsOneWidget);
    });

    testWidgets('connected: both green with their hosts, and the budget sheet switches', (tester) async {
      await pump(tester, values: connected);
      expect(find.text('Connected · 10.0.0.2', findRichText: true), findsOneWidget);
      expect(find.text('Connected · actual.lan', findRichText: true), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Match with Actual'), findsOneWidget);

      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      expect(find.text('Budgets on actual.lan. Imports and category memory follow the one you pick.'), findsOneWidget);
      await tester.tap(find.text('Side Hustle'));
      await tester.pumpAndSettle();

      expect(prefs.getString('budget_sync_id'), 'side');
      expect(find.text('Switched to "Side Hustle".'), findsOneWidget);
    });

    testWidgets('a backend that is down shows as failing, and Actual as waiting on it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, values: connected);
      api.status = HealthStatus.unreachable;
      await tester.tap(find.text('Backend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not reach the importer'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text("Can't reach it · 10.0.0.2", findRichText: true), findsOneWidget);
      expect(find.text('Needs the backend'), findsOneWidget);
    });

    testWidgets('a backend without Actual: Actual is not set up', (tester) async {
      await pump(tester, values: {'backend_url': 'http://10.0.0.2:3000'});
      api.actualConfigured = false;
      await tester.tap(find.text('Backend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and test'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Not set up'), findsOneWidget);
      expect(find.text('Connect Actual first'), findsOneWidget);
    });

    testWidgets('forgetting statement passwords asks first', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Forget statement passwords'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(secrets.forgotten, 0);

      await tester.tap(find.text('Forget statement passwords'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();
      expect(secrets.forgotten, 1);
      expect(find.text('Statement passwords forgotten.'), findsOneWidget);
    });

    testWidgets('rows open their screens', (tester) async {
      await pump(tester, values: connected);
      await tester.tap(find.text('Backups'));
      await tester.pumpAndSettle();
      expect(find.text('BACKUPS'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('320dp wide at 200% text (${dark ? 'dark' : 'light'}): nothing overflows', (tester) async {
        await pump(tester, values: connected, size: const Size(320, 640), textScale: 2, dark: dark);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Run setup again'), 200);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(find.text('Backend'), -200);
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Backend'));
        await tester.pumpAndSettle();
        expect(find.text('Save and test'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Actual'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Budget'));
        await tester.pumpAndSettle();
        expect(find.text('Side Hustle'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
