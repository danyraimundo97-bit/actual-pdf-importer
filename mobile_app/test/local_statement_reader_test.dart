import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/pdf/local_statement_reader.dart';
import 'package:mobile_app/data/pdf/pdf_text_extractor.dart';

/// Returns fixed text, or throws, without touching PDFium.
class FakeExtractor implements PdfTextExtractor {
  FakeExtractor({this.text = '', this.failure});

  final String text;
  final PdfReadFailure? failure;
  String? lastPassword;

  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    lastPassword = password;
    if (failure != null) throw PdfReadException(failure!);
    return text;
  }
}

String fixture(String name) => File('../fixtures/parsers/$name').readAsStringSync();

void main() {
  final bytes = Uint8List(0);

  test('reads a recognised statement into transactions with ids', () async {
    final expected = jsonDecode(fixture('moey-basic.expected.json')) as Map<String, Object?>;
    final reader = LocalStatementReader(FakeExtractor(text: fixture('moey-basic.pdfium.txt')));

    final result = await reader.read(bytes);

    expect(result.bankId, 'moey');
    expect(result.transactions.length, (expected['transactions'] as List).length);
    expect(result.transactions.every((t) => t.importedId.startsWith('pdfimport-')), isTrue);
  });

  test('an unrecognised statement is a result, not an error', () async {
    final reader = LocalStatementReader(FakeExtractor(text: 'Some other bank\n01-01-2026 COFFEE 2,50'));

    final result = await reader.read(bytes);

    expect(result.recognised, isFalse);
    expect(result.transactions, isEmpty);
  });

  test('passes the password through and lets password failures out', () async {
    final extractor = FakeExtractor(failure: PdfReadFailure.passwordIncorrect);
    final reader = LocalStatementReader(extractor);

    await expectLater(
      reader.read(bytes, password: 'secret'),
      throwsA(isA<PdfReadException>().having((e) => e.code, 'code', 'PDF_PASSWORD_INCORRECT')),
    );
    expect(extractor.lastPassword, 'secret');
  });
}
