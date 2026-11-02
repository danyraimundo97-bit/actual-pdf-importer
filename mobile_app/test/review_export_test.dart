import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/data/models/actual_account.dart';
import 'package:mobile_app/data/models/parse_result.dart';
import 'package:mobile_app/data/models/parsed_transaction.dart';
import 'package:mobile_app/data/providers.dart';
import 'package:mobile_app/features/review/csv_export.dart';
import 'package:mobile_app/features/review/screens/review_screen.dart';
import 'package:mobile_app/features/review/screens/review_screen_args.dart';

ParsedTransaction tx(String payee, int cents, {String? category, bool include = true}) => ParsedTransaction(
  date: DateTime(2026, 7, 3),
  payee: payee,
  amountCents: cents,
  rawLine: '',
  importedId: 'pdfimport-1',
  suggestedCategoryId: category == null ? null : 'id-$category',
  suggestedCategoryName: category,
  include: include,
);

void main() {
  group('CSV', () {
    test('header, ISO dates, plain decimal amounts, category names', () {
      final csv = transactionsToCsv([tx('SHOP', -1230, category: 'Groceries'), tx('SALARY', 150000)]);
      expect(csv, 'date,payee,amount,category\r\n2026-07-03,SHOP,-12.30,Groceries\r\n2026-07-03,SALARY,1500.00,\r\n');
    });

    test('quotes fields with commas, quotes or line breaks', () {
      final csv = transactionsToCsv([tx('Café "Central", Lda', -5)]);
      expect(csv.split('\r\n')[1], '2026-07-03,"Café ""Central"", Lda",-0.05,');
    });

    test('a category the user picked wins over the suggestion', () {
      final picked = tx(
        'SHOP',
        -100,
        category: 'Groceries',
      ).copyWith(overrideCategoryId: 'id-home', overrideCategoryName: 'Home');
      expect(transactionsToCsv([picked]).split('\r\n')[1], endsWith(',Home'));
    });

    test('amounts never go through a double', () {
      expect(centsToDecimal(0), '0.00');
      expect(centsToDecimal(-1), '-0.01');
      expect(centsToDecimal(123456789), '1234567.89');
    });

    test('bytes start with a UTF-8 byte order mark', () {
      expect(csvBytes('a').take(3), [0xEF, 0xBB, 0xBF]);
    });
  });

  group('Review', () {
    Future<void> pumpReview(WidgetTester tester, {ActualAccount? account}) async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
          child: MaterialApp(
            home: ReviewScreen(
              args: ReviewScreenArgs(
                parseResult: ParseResult(bankId: 'moey', transactions: [tx('SHOP', -1230), tx('CAFE', -250)]),
                account: account,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('without an account it offers CSV export instead of import', (tester) async {
      await pumpReview(tester);

      expect(find.text('Export 2 as CSV'), findsOneWidget);
      expect(find.textContaining('Import'), findsNothing);
      expect(find.textContaining('Connect Actual to import'), findsOneWidget);
    });
  });
}
