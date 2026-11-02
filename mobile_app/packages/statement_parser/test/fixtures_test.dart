import 'dart:convert';
import 'dart:io';

import 'package:statement_parser/statement_parser.dart';
import 'package:test/test.dart';

/// The repo's shared fixtures (`fixtures/`), read by the backend's tests too.
/// `dart test` runs from the package root.
final fixtures = Directory('../../../fixtures');

void main() {
  group('parser fixtures', () {
    final cases =
        Directory('${fixtures.path}/parsers')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.expected.json'))
            .map((f) => f.path.replaceFirst(RegExp(r'\.expected\.json$'), ''))
            .toList()
          ..sort();

    test('are there', () => expect(cases, isNotEmpty));

    for (final base in cases) {
      final name = base.split('/').last;
      final expected = jsonDecode(File('$base.expected.json').readAsStringSync()) as Map<String, dynamic>;
      // pdf.js is the backend's shape, PDFium the app's.
      for (final shape in ['pdfjs', 'pdfium']) {
        final file = File('$base.$shape.txt');
        if (!file.existsSync()) continue;
        test('$name ($shape)', () {
          final result = parseStatementText(file.readAsStringSync());
          expect(result.bankId, expected['bankId']);
          expect([
            for (final t in result.transactions) {'date': t.date, 'payee': t.payee, 'amountCents': t.amountCents},
          ], expected['transactions']);
        });
      }
    }
  });

  group('golden importedIds', () {
    final golden = jsonDecode(File('${fixtures.path}/imported-ids.json').readAsStringSync()) as Map<String, dynamic>;
    for (final c in (golden['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final txs = [
          for (final t in (c['transactions'] as List).cast<Map<String, dynamic>>())
            (date: t['date'] as String, amountCents: t['amountCents'] as int, payee: t['payee'] as String),
        ];
        expect(assignImportedIds(txs), c['importedIds']);
      });
    }
  });
}
