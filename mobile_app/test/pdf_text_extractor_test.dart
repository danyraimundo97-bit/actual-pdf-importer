import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/pdf/pdf_text_extractor.dart';
import 'package:pdfrx/pdfrx.dart' show Pdfrx, pdfrxInitialize;
import 'package:statement_parser/statement_parser.dart';

// The PDFium library pdfium_dart's build hook downloaded for this machine.
// `flutter test` runs the hook but doesn't hand its native assets to the
// host test runner, so point pdfrx at the file. Absent before the first
// build (e.g. no C compiler): the PDF tests skip and say why.
final pdfium = [
  'build/native_assets/linux/libpdfium.so',
  'build/native_assets/macos/libpdfium.dylib',
  'build/native_assets/windows/pdfium.dll',
].map(File.new).where((f) => f.existsSync()).firstOrNull;

// The real PDFium, through pdfrx. Plain-Dart initialisation, since
// pdfrxFlutterInitialize needs platform channels a host test doesn't have.
final extractor = PdfrxTextExtractor(
  initialize: () {
    Pdfrx.pdfiumModulePath ??= pdfium?.absolute.path;
    return pdfrxInitialize();
  },
);

// The backend's encrypted fixture (password "1234"), shared rather than
// copied so both projects test the same file.
final encrypted = File('../backend_app/src/__fixtures__/encrypted-statement.pdf');

// Real statements, local only (gitignored, see docs/plans/dart-parser.md).
final realDir = Directory('../backend_app/Docs/tests');

void main() {
  final noPdfium = pdfium == null ? 'PDFium not built yet: run `flutter build linux` (needs clang) once' : null;

  group('passwords', skip: noPdfium, () {
    test('no password on an encrypted PDF is "required"', () async {
      await expectLater(
        extractor.extractText(encrypted.readAsBytesSync()),
        throwsA(isA<PdfReadException>().having((e) => e.code, 'code', 'PDF_PASSWORD_REQUIRED')),
      );
    });

    test('a wrong password is "incorrect"', () async {
      await expectLater(
        extractor.extractText(encrypted.readAsBytesSync(), password: 'wrong-password'),
        throwsA(isA<PdfReadException>().having((e) => e.code, 'code', 'PDF_PASSWORD_INCORRECT')),
      );
    });

    test('the right password opens it', () async {
      final text = await extractor.extractText(encrypted.readAsBytesSync(), password: '1234');
      expect(text.trim(), isNotEmpty);
    });

    test('an empty password counts as none', () async {
      await expectLater(
        extractor.extractText(encrypted.readAsBytesSync(), password: ''),
        throwsA(isA<PdfReadException>().having((e) => e.code, 'code', 'PDF_PASSWORD_REQUIRED')),
      );
    });
  });

  test('a file that is not a PDF is "unreadable"', skip: noPdfium, () async {
    await expectLater(
      extractor.extractText(utf8.encode('not a pdf at all')),
      throwsA(isA<PdfReadException>().having((e) => e.code, 'code', 'PDF_UNREADABLE')),
    );
  });

  // Same check as the parser package's real_statements_test, but from the
  // PDF itself: extraction + parsing on the device must give exactly what
  // the backend's /parse gave. Prints counts only, never statement content.
  group('real statements', skip: noPdfium, () {
    final pdfs = realDir.existsSync()
        ? (realDir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];

    test('folder present', () {}, skip: pdfs.isEmpty ? 'no real statements in ${realDir.path}' : false);

    for (final pdf in pdfs) {
      final name = pdf.uri.pathSegments.last.replaceAll('.pdf', '');
      final extraction = File('${realDir.path}/$name Extraction.json');
      if (!extraction.existsSync()) continue;

      test('statement ${pdfs.indexOf(pdf) + 1} matches the backend', () async {
        final expected = jsonDecode(extraction.readAsStringSync()) as Map<String, Object?>;
        final want = (expected['transactions'] as List).cast<Map<String, Object?>>();

        final result = parseStatementText(await extractor.extractText(pdf.readAsBytesSync()));

        expect(result.bankId, expected['bankId']);
        expect(result.warnings, isEmpty);
        expect(result.transactions.length, want.length);
        var mismatches = 0;
        for (final (i, t) in result.transactions.indexed) {
          final w = want[i];
          if (t.date != w['date'] ||
              t.payee != w['payee'] ||
              t.amountCents != w['amountCents'] ||
              t.importedId != w['importedId']) {
            mismatches++;
          }
        }
        expect(mismatches, 0, reason: '$mismatches of ${want.length} movements differ');
        // ignore: avoid_print
        print('${result.bankId}: ${want.length} movements match');
      });
    }
  });
}
