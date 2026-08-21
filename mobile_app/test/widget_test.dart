// Minimal smoke test: replaces the flutter-create counter-app test (that
// widget no longer exists). Verifies the app boots and that the first-run
// gate (see core/router.dart's redirect) sends a user with no configured
// backend URL to Settings instead of Import.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('boots to Settings when no backend URL is configured', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ImporterApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}
