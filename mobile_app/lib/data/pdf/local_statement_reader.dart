import 'package:flutter/foundation.dart';
import 'package:statement_parser/statement_parser.dart';

import '../../core/log/app_log.dart';
import 'pdf_text_extractor.dart';

const _log = AppLog('pdf');

/// Reads a statement entirely on the device: PDF text, bank detection,
/// movements and dedupe ids. No network.
class LocalStatementReader {
  LocalStatementReader(this._extractor);

  final PdfTextExtractor _extractor;

  /// Throws [PdfReadException] when the PDF can't be opened. An
  /// unrecognised bank is not an error: the result says
  /// `recognised == false` and the caller decides what to offer.
  Future<StatementParseResult> read(Uint8List bytes, {String? password}) async {
    final text = await _extractor.extractText(bytes, password: password);
    // Parsing is pure Dart and can take a moment on a long statement, so it
    // runs off the UI isolate (inline on web, where there are none).
    final result = await compute(parseStatementText, text);

    // Never the text, amounts or balances; payees only at debug.
    _log.info('Statement read on device', {
      'bank': result.bankId,
      'transactions': result.transactions.length,
      'warnings': result.warnings.length,
    });
    for (final warning in result.warnings) {
      _log.warn('Parser warning: ${warning.message}', {'bank': warning.bankId, ...warning.fields});
      if (warning.payee != null) {
        _log.debug('Parser warning payee', {'bank': warning.bankId, 'payee': warning.payee});
      }
    }
    return result;
  }
}
