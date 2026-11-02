import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Why a statement's text couldn't be read on the device.
enum PdfReadFailure {
  passwordRequired('PDF_PASSWORD_REQUIRED'),
  passwordIncorrect('PDF_PASSWORD_INCORRECT'),
  unreadable('PDF_UNREADABLE');

  /// The backend's error code for the same case (backend_app/src/errors.ts),
  /// so the inbox can treat a local failure like a `/parse` answer.
  final String code;
  const PdfReadFailure(this.code);
}

class PdfReadException implements Exception {
  final PdfReadFailure failure;
  const PdfReadException(this.failure);

  String get code => failure.code;

  @override
  String toString() => 'PdfReadException($code)';
}

/// Reads the text of a statement PDF. Bytes stay in memory: nothing is
/// written to disk, same as the backend's upload handling.
abstract interface class PdfTextExtractor {
  /// The text of every page, pages joined by `\n`. Throws
  /// [PdfReadException] for a missing or wrong password or a file that
  /// isn't a readable PDF.
  Future<String> extractText(Uint8List bytes, {String? password});
}

/// PDFium through `pdfrx`. Its PDFium calls already run on pdfrx's own
/// background worker, so this doesn't block the UI isolate.
class PdfrxTextExtractor implements PdfTextExtractor {
  /// [initialize] defaults to `pdfrxFlutterInitialize`; plain-Dart tests
  /// pass `pdfrxInitialize` instead.
  PdfrxTextExtractor({Future<void> Function()? initialize}) : _initialize = initialize ?? pdfrxFlutterInitialize;

  final Future<void> Function() _initialize;

  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    await _initialize();
    final hasPassword = password != null && password.isNotEmpty;

    // pdfrx first tries no password, then asks the provider; a provider
    // that has nothing (left) to give ends in PdfPasswordException. So that
    // exception means "required" when we had no password and "incorrect"
    // when ours was tried and rejected.
    final PdfDocument document;
    try {
      document = await PdfDocument.openData(
        bytes,
        passwordProvider: createSimplePasswordProvider(hasPassword ? password : null),
      );
    } on PdfPasswordException {
      throw PdfReadException(hasPassword ? PdfReadFailure.passwordIncorrect : PdfReadFailure.passwordRequired);
    } on PdfException {
      throw const PdfReadException(PdfReadFailure.unreadable);
    }

    try {
      final pages = <String>[];
      for (final page in document.pages) {
        pages.add((await page.loadText())?.fullText ?? '');
      }
      return pages.join('\n');
    } on PdfException {
      throw const PdfReadException(PdfReadFailure.unreadable);
    } finally {
      await document.dispose();
    }
  }
}
