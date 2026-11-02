import '../statement_scanner.dart';
import '../types.dart';
import 'bank_parser.dart';

/// moey (Crédito Agrícola). Port of `backend_app/src/parsers/moey.ts`.
///
/// pdf.js (backend):
///
///     01-07-2026  /  01-07-2026COMPRA BRISANORTE   9898237/51
///       2,60  -53,16
///
/// PDFium (app):
///
///     01-07-2026 / 01-07-2026 COMPRA BRISANORTE 9898237/51 2,60 - 53,16
///
/// - The amount has no sign of its own: the +/- before the balance is the
///   direction ("+-9,77" or "+ -9,77" = money in, new balance -9,77).
/// - Long descriptions wrap, in both shapes, so a movement is a block of
///   lines starting at a date line.
/// - Every page repeats a header, which can fall in the middle of a block.
/// - A savings-account section after the first "SALDO FINAL" mirrors
///   transfers already listed; it's ignored.
class MoeyParser implements BankParser {
  const MoeyParser();

  @override
  String get bankId => 'moey';

  static final _noisePrefixes = [
    RegExp(r'^Compra\s+online\s*', caseSensitive: false),
    RegExp(r'^DEV\s+COMPRA\s*', caseSensitive: false),
    RegExp(r'^Compra\s*', caseSensitive: false),
    RegExp(r'^IPS/R\d+-\s*', caseSensitive: false),
    RegExp(r'^Pagamento\s+MB\s*WAY\s*', caseSensitive: false),
    RegExp(r'^MB\s*WAY\s*', caseSensitive: false),
    RegExp(r'^TRANSF\s+SEPA\s*-\s*', caseSensitive: false),
    RegExp(r'^Trf\s+imediata\s*', caseSensitive: false),
    RegExp(r'^Trsf\.?\s*p/\s*', caseSensitive: false),
    RegExp(r'^Transferencia\s+enviada\s*', caseSensitive: false),
    RegExp(r'^Transferencia\s+recebida\s*', caseSensitive: false),
    RegExp(r'^PAG-\s*', caseSensitive: false),
    RegExp(r'^Levant\w*\s*', caseSensitive: false),
  ];

  static final _dateLine = RegExp(r'^(\d{2}-\d{2}-\d{4})\s+/\s+\d{2}-\d{2}-\d{4}(.*)$');
  static const _amount = r'\d{1,3}(?:\.\d{3})*,\d{2}';
  // PDFium puts a space between the sign and the balance; pdf.js doesn't.
  static final _block = RegExp('^(.*?)\\s+($_amount)\\s+([+-])\\s?(-?$_amount)\$');
  // Page code line, then the repeated column header that ends the break.
  static final _headerRegion = (RegExp(r'^[A-Z]{3,}\d{2,}\w*$'), RegExp(r'^ACCOUNT DATE\s*/\s*VALUE DATE'));
  static final _sectionEnd = RegExp(r'^SALDO FINAL');

  @override
  bool canParse(String fullText) => RegExp('moey', caseSensitive: false).hasMatch(fullText);

  @override
  List<RawTransaction> parse(String fullText, WarningSink warn) {
    final transactions = <RawTransaction>[];
    final blocks = scanMovementBlocks(
      fullText,
      ScanConfig(dateLine: _dateLine, endAt: _sectionEnd, skipRegion: _headerRegion),
    );

    for (final b in blocks) {
      final movementDate = b.date[1]!;
      // date[2] is the rest of the date line: where the description starts.
      final block = squash([b.date[2]!, ...b.lines].join(' '));
      final match = _block.firstMatch(block);
      if (match == null) {
        // Not a movement, or its amount/balance got lost. Never silent; the
        // block itself isn't reported (it carries amounts).
        warn(
          ParseWarning(
            bankId,
            'Skipped a block with no amount/balance',
            fields: {'date': movementDate, 'lines': b.lines.length + 1},
          ),
        );
        continue;
      }

      final description = match[1]!;
      try {
        final cents = parsePtAmountToCents(match[2]!);
        transactions.add(
          RawTransaction(
            date: normalizePtDate(movementDate),
            payee: _cleanPayee(description),
            amountCents: match[3] == '-' ? -cents : cents,
            rawLine: '$movementDate $block',
          ),
        );
      } on FormatException catch (e) {
        warn(
          ParseWarning(
            bankId,
            'Skipped an unparseable block',
            fields: {'date': movementDate, 'reason': e.message},
            payee: _cleanPayee(description),
          ),
        );
      }
    }

    return transactions;
  }

  static String _cleanPayee(String rawPayee) {
    // The trailing "9898237/51" card reference differs on every transaction.
    var payee = rawPayee.replaceFirst(RegExp(r'\s+\d{5,}/\d+$'), '').trim();
    payee = stripFirstPrefix(payee, _noisePrefixes);
    return squash(payee);
  }
}
