import 'dart:convert';
import 'dart:io';

import 'package:statement_parser/statement_parser.dart';
import 'package:test/test.dart';

/// Local-only check against real statements, never committed:
/// `backend_app/Docs/tests/` (gitignored) holds, per statement,
///
/// - `<name>.pdfium.txt`: the text PDFium extracts (what the app will see)
/// - `<name> Extraction.json`: what the backend parsed from the same PDF
///
/// The app must read exactly what the backend did, `importedId` included,
/// or statements already imported come back as duplicates. Skipped when the
/// folder is absent (CI, other clones).
///
/// Failures print dates and counts only, never payees or amounts.
void main() {
  final dir = Directory('../../../backend_app/Docs/tests');
  final dumps = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdfium.txt')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  if (dumps.isEmpty) {
    test('real statements', () {}, skip: 'no statements in backend_app/Docs/tests');
    return;
  }

  for (final dump in dumps) {
    final base = dump.path.replaceFirst(RegExp(r'\.pdfium\.txt$'), '');
    final name = base.split('/').last;
    final expectedFile = File('$base Extraction.json');

    test(name, () {
      if (!expectedFile.existsSync()) fail('missing "$name Extraction.json"');
      final expected = jsonDecode(expectedFile.readAsStringSync()) as Map<String, dynamic>;
      final want = (expected['transactions'] as List).cast<Map<String, dynamic>>();
      final result = parseStatementText(dump.readAsStringSync());
      final got = result.transactions;

      expect(result.bankId, expected['bankId'], reason: 'bank');
      expect(
        got.length,
        want.length,
        reason: 'movement count (warnings: ${result.warnings.map((w) => '${w.message} ${w.fields}').toList()})',
      );

      final mismatches = <String>[];
      for (var i = 0; i < want.length; i++) {
        final w = want[i];
        final g = got[i];
        final fields = [
          if (g.date != w['date']) 'date',
          if (g.payee != w['payee']) 'payee',
          if (g.amountCents != w['amountCents']) 'amount',
          if (g.importedId != w['importedId']) 'importedId',
        ];
        if (fields.isNotEmpty) mismatches.add('#$i (${w['date']}): ${fields.join(', ')}');
      }
      expect(mismatches, isEmpty);
    });
  }
}
