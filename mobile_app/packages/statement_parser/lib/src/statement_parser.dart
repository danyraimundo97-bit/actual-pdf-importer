import 'imported_id.dart';
import 'parsers/activobank.dart';
import 'parsers/bank_parser.dart';
import 'parsers/moey.dart';
import 'parsers/traderepublic.dart';
import 'types.dart';

/// The local parsers, in the backend's order (`REGEX_PARSERS` in
/// `backend_app/src/index.ts`).
const List<BankParser> bankParsers = [ActivoBankParser(), MoeyParser(), TradeRepublicParser()];

/// A transaction with its dedupe id.
class ParsedTransaction extends RawTransaction {
  final String importedId;

  const ParsedTransaction({
    required super.date,
    required super.payee,
    required super.amountCents,
    required super.rawLine,
    required this.importedId,
  });
}

class StatementParseResult {
  /// Null when no local parser recognised the text.
  final String? bankId;
  final List<ParsedTransaction> transactions;
  final List<ParseWarning> warnings;

  const StatementParseResult({required this.bankId, required this.transactions, required this.warnings});

  bool get recognised => bankId != null;
}

/// Line endings as the parsers expect them: PDFium ends lines with `\r\n`,
/// and a page break (if the extractor marks one) is just another line break.
String normalizeExtractedText(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\f', '\n');

/// Detects the bank by content and reads every movement, with dedupe ids.
///
/// Accepts both text shapes: pdf.js (the backend's extractor) and PDFium
/// (the app's), with `\r\n` or `\n` line endings.
StatementParseResult parseStatementText(String text) {
  final normalized = normalizeExtractedText(text);
  final warnings = <ParseWarning>[];
  for (final parser in bankParsers) {
    if (!parser.canParse(normalized)) continue;
    final raw = parser.parse(normalized, warnings.add);
    final ids = assignImportedIds([for (final t in raw) (date: t.date, amountCents: t.amountCents, payee: t.payee)]);
    return StatementParseResult(
      bankId: parser.bankId,
      transactions: [
        for (var i = 0; i < raw.length; i++)
          ParsedTransaction(
            date: raw[i].date,
            payee: raw[i].payee,
            amountCents: raw[i].amountCents,
            rawLine: raw[i].rawLine,
            importedId: ids[i],
          ),
      ],
      warnings: warnings,
    );
  }
  return StatementParseResult(bankId: null, transactions: const [], warnings: warnings);
}
