import '../statement_scanner.dart';
import '../types.dart';
import 'bank_parser.dart';

/// Trade Republic. Port of `backend_app/src/parsers/traderepublic.ts`.
///
/// pdf.js (backend):
///
///     03 ago.                                  <- day + abbreviated PT month
///     2026                                     <- year, on its own line
///     Transação com                            <- type (wraps)
///     cartão
///     PETROPRIX MATOSINHOS 420,00 €3 551,98 €  <- description, amount, balance
///
/// PDFium (app) keeps the gaps, and puts the year in front of the row when
/// the type fits on one line:
///
///     03 ago.
///     2026
///     Transação com
///     cartão PETROPRIX MATOSINHOS 4 20,00 € 3 551,98 €
///     01 ago.
///     2026 Juros Interest payment 7,82 € 3 571,98 €
///
/// ENTRADA and SAÍDA DE DINHEIRO are separate columns, so nothing in the text
/// says which way money moved, and in pdf.js text the description runs into
/// the amount ("…MATOSINHOS 420,00" is the payee "…MATOSINHOS 4" plus
/// 20,00). Both are settled by the running balance: the change from the
/// previous balance is the signed amount, and its printed form is what's cut
/// off the end of the description.
class TradeRepublicParser implements BankParser {
  const TradeRepublicParser();

  @override
  String get bankId => 'traderepublic';

  static const _amount = r'\d{1,3}(?: \d{3})*,\d{2}';
  static final _dateLine = RegExp(
    r'^(\d{1,2})\s+(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\.?$',
    caseSensitive: false,
  );
  // PDFium may continue the row on the year line (group 2).
  static final _yearLine = RegExp(r'^(\d{4})(?:\s+(.*))?$');
  // Only the balance is unambiguous: the last €-terminated number.
  static final _balanceTail = RegExp('^(.*?)($_amount)\\s*€\$');
  static final _openingBalance = RegExp('SALDO\\s*INICIAL[\\s\\S]*?($_amount)\\s*€', caseSensitive: false);
  static final _sectionStart = RegExp(r'^TRANSA[ÇC][ÕO]ES$');
  static final _sectionEnd = RegExp(r'^S[IÍ]NTESE DO BALAN[ÇC]O$');
  // Every page repeats an address footer then the column headers, which end
  // in "SALDO" (pdf.js) or "DINHEIRO SALDO" (PDFium). Skipping them as a
  // region avoids denylisting lines that include personal names.
  static final _footerRegion = (
    RegExp(r'^TRADE REPUBLIC BANK GMBH', caseSensitive: false),
    RegExp(r'^(?:DINHEIRO\s+)?SALDO$', caseSensitive: false),
  );

  static const _months = {
    'jan': 1, 'fev': 2, 'mar': 3, 'abr': 4, 'mai': 5, 'jun': 6, //
    'jul': 7, 'ago': 8, 'set': 9, 'out': 10, 'nov': 11, 'dez': 12,
  };

  static final _typePrefixes = [
    RegExp(r'^Transa[çc][ãa]o com cart[ãa]o\s*', caseSensitive: false),
    RegExp(r'^Transfer[êe]ncia\s*', caseSensitive: false),
    RegExp(r'^Juros\s*', caseSensitive: false),
    RegExp(r'^Imposto\s*', caseSensitive: false),
    RegExp(r'^Taxa\s*', caseSensitive: false),
    RegExp(r'^Dividendo\s*', caseSensitive: false),
  ];

  static final _descriptionPrefixes = [
    RegExp(r'^Incoming transfer from\s*', caseSensitive: false),
    RegExp(r'^Outgoing transfer (?:for|to)\s*', caseSensitive: false),
  ];

  @override
  bool canParse(String fullText) =>
      // The full legal name: a moey statement lists "TRANSF SEPA -Trade
      // Republic Ba" as a payee, and a looser sniff would claim it.
      RegExp(r'trade\s*republic\s*bank\s*gmbh', caseSensitive: false).hasMatch(fullText);

  @override
  List<RawTransaction> parse(String fullText, WarningSink warn) {
    // Both extractors give NBSP for thousands and currency gaps; plain
    // spaces from here on.
    final text = fullText.replaceAll(' ', ' ');

    final scanned = <_Scanned>[];
    final blocks = scanMovementBlocks(
      text,
      ScanConfig(dateLine: _dateLine, startAt: _sectionStart, endAt: _sectionEnd, skipRegion: _footerRegion),
    );
    for (final block in blocks) {
      final day = int.parse(block.date[1]!);
      final month = _months[block.date[2]!.toLowerCase()]!;
      final year = block.lines.isEmpty ? null : _yearLine.firstMatch(block.lines.first);
      if (year == null) {
        warn(ParseWarning(bankId, 'No year line after a date line; skipping', fields: {'day': day, 'month': month}));
        continue;
      }
      final body = squash([year[2] ?? '', ...block.lines.skip(1)].join(' '));
      final tail = _balanceTail.firstMatch(body);
      if (tail == null) {
        warn(
          ParseWarning(
            bankId,
            'No amount/balance found; skipping',
            fields: {'day': day, 'month': month, 'year': year[1]},
          ),
        );
        continue;
      }
      scanned.add(
        _Scanned(
          date: '${year[1]}-${pad2(month)}-${pad2(day)}',
          head: tail[1]!.replaceFirst(RegExp(r'\s*€\s*$'), '').trimRight(),
          balance: parsePtAmountToCents(tail[2]!),
          rawLine: squash([block.dateLine, ...block.lines].join(' ')),
        ),
      );
    }

    if (scanned.isEmpty) return [];

    // The opening balance anchors the first delta. Without it only the
    // first movement is lost: the rest still follow from printed balances.
    final anchor = _openingBalance.firstMatch(text);
    if (anchor == null) {
      warn(ParseWarning(bankId, 'No SALDO INICIAL in the summary block; the first movement will be skipped'));
    }
    var balance = anchor != null ? parsePtAmountToCents(anchor[1]!) : scanned.first.balance;
    final resolvable = anchor != null ? scanned : scanned.skip(1);

    final transactions = <RawTransaction>[];
    for (final movement in resolvable) {
      final amountCents = movement.balance - balance;
      balance = movement.balance;

      final printed = _formatCents(amountCents);
      if (!movement.head.endsWith(printed)) {
        warn(
          ParseWarning(
            bankId,
            'The balance change is not the amount printed on the line; skipping',
            fields: {'date': movement.date},
            payee: _cleanPayee(_stripType(movement.head)),
          ),
        );
        continue;
      }
      transactions.add(
        RawTransaction(
          date: movement.date,
          payee: _cleanPayee(_stripType(movement.head.substring(0, movement.head.length - printed.length).trim())),
          amountCents: amountCents,
          rawLine: movement.rawLine,
        ),
      );
    }

    return transactions;
  }

  /// Cents as the statement prints them ("1 145,00"), so the exact amount
  /// text can be cut off the end of a description. Comparing numerically
  /// wouldn't work: "LOJA TESTE 410,00" ends in 410,00 but the amount is 10,00.
  static String _formatCents(int cents) {
    final abs = cents.abs();
    final whole = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    return '$whole,${pad2(abs % 100)}';
  }

  static String _cleanPayee(String rawPayee) {
    var payee = stripFirstPrefix(rawPayee.trim(), _descriptionPrefixes);
    // A trailing IBAN in parentheses never varies for one payee but makes
    // the category key needlessly long.
    payee = payee.replaceFirst(RegExp(r'\s*\(\s*[A-Z]{2}\d{2}[0-9A-Z]{4,}\s*\)\s*$', caseSensitive: false), '');
    return squash(payee);
  }

  static String _stripType(String description) => stripFirstPrefix(description, _typePrefixes);
}

class _Scanned {
  final String date;

  /// Type + description + the amount text, not yet separated.
  final String head;
  final int balance;
  final String rawLine;

  const _Scanned({required this.date, required this.head, required this.balance, required this.rawLine});
}
