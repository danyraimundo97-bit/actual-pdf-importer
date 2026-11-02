import '../statement_scanner.dart';
import '../types.dart';
import 'bank_parser.dart';

/// ActivoBank. Port of `backend_app/src/parsers/activobank.ts`.
///
/// A movement, as pdf.js extracts it (backend):
///
///     7.01  7.01                            <- posting / value date, MONTH.DAY
///     COMPRA 2902 STEAM PURCHASE SEATTLE    <- description (may wrap)
///     34.99265.16                           <- amount AND balance, glued
///
/// and as PDFium extracts it (app), one line:
///
///     7.01 7.01 COMPRA 2902 STEAM PURCHASE SEATTLE 34.99 265.16
///
/// - The date has no year; it comes from "EXTRATO DE yyyy/mm/dd A …".
/// - Amounts use "." for decimals and a space for thousands ("1 386.35").
/// - No sign: DEBITO and CREDITO are columns, which text extraction
///   flattens. Direction, and where the amount ends and the balance starts,
///   are both recovered from the running balance ([_resolve]).
class ActivoBankParser implements BankParser {
  const ActivoBankParser();

  @override
  String get bankId => 'activobank';

  // Longer, more specific prefixes first: only the first match is stripped,
  // so "COMPRA 2902 X" must be tried before "COMPRA X".
  static final _noisePrefixes = [
    RegExp(r'^COMPRA\s+ONLINE\s*', caseSensitive: false),
    RegExp(r'^COMPRA\s+CARTAO\s*', caseSensitive: false),
    RegExp(r'^COMPRA\s+\d{3,4}\s+', caseSensitive: false), // 4-digit card terminal
    RegExp(r'^COMPRA\s*', caseSensitive: false),
    RegExp(r'^TRF\s+MB\s*WAY\s+P/\s*', caseSensitive: false),
    RegExp(r'^TRF\s+P/\s*', caseSensitive: false),
    RegExp(r'^TRF\s*', caseSensitive: false),
    RegExp(r'^MB\s*WAY\s+PAGAMENTO\s*', caseSensitive: false),
    RegExp(r'^MB\s*WAY\s+LEVANTAMENTO\s*', caseSensitive: false),
    RegExp(r'^MB\s*WAY\s*', caseSensitive: false),
    RegExp(r'^LEVANTAMENTO\s+ATM\s*', caseSensitive: false),
    RegExp(r'^LEVANTAMENTO\s*', caseSensitive: false),
    RegExp(r'^TRANSFERENCIA\s+MB\s*', caseSensitive: false),
    RegExp(r'^TRANSFERENCIA\s*-\s*', caseSensitive: false),
    RegExp(r'^TRANSFERENCIA\s*', caseSensitive: false),
    RegExp(r'^PAGAMENTO\s+SERVICOS?\s*', caseSensitive: false),
    RegExp(r'^PAG\.\s*', caseSensitive: false),
    RegExp(r'^DEBITO\s+DIRETO\s*', caseSensitive: false),
    RegExp(r'^DD\s+', caseSensitive: false), // direct debit
  ];

  static const _amount = r'\d{1,3}(?:[  ]\d{3})*\.\d{2}';
  static final _amountOnly = RegExp('^$_amount\$');
  // The rest of the line (group 5) is the whole row in PDFium's text.
  static final _dateLine = RegExp(r'^(\d{1,2})\.(\d{2})\s+(\d{1,2})\.(\d{2})(?:\s+(.*))?$');
  static final _period = RegExp(r'EXTRATO DE\s*\n?\s*(\d{4})/(\d{2})/\d{2}\s+A\s+\d{4}/(\d{2})/\d{2}');
  static final _openingBalance = RegExp('SALDO INICIAL\\s*?($_amount)');
  static final _tableStart = RegExp(r'^SALDO INICIAL');
  static final _tableEnd = RegExp(r'^SALDO FINAL');

  @override
  bool canParse(String fullText) {
    if (!RegExp(r'activo\s*bank', caseSensitive: false).hasMatch(fullText)) return false;
    // A statement that merely *mentions* ActivoBank (a transfer payee on
    // another bank's statement) is not an ActivoBank statement.
    return RegExp(r'banco\s*activobank', caseSensitive: false).hasMatch(fullText) ||
        RegExp(r'DESCRITIVO\s*DEBITO\s*CREDITO\s*SALDO', caseSensitive: false).hasMatch(fullText);
  }

  @override
  List<RawTransaction> parse(String fullText, WarningSink warn) {
    final period = _period.firstMatch(fullText);
    if (period == null) {
      // No year anywhere in the table: nothing can be dated.
      warn(ParseWarning(bankId, 'No "EXTRATO DE yyyy/mm/dd A yyyy/mm/dd" period header; cannot date movements'));
      return [];
    }
    final startYear = int.parse(period[1]!);
    final startMonth = int.parse(period[2]!);

    final opening = _openingBalance.firstMatch(fullText);
    if (opening == null) {
      warn(ParseWarning(bankId, 'No readable SALDO INICIAL; movement direction cannot be resolved'));
      return [];
    }
    if (RegExp(r'^SALDO INICIAL', multiLine: true).allMatches(fullText).length > 1) {
      warn(ParseWarning(bankId, 'Statement contains more than one account table; only the first was parsed'));
    }

    final blocks = scanMovementBlocks(
      fullText,
      ScanConfig(dateLine: _dateLine, startAt: _tableStart, endAt: _tableEnd),
    );

    final transactions = <RawTransaction>[];
    var balance = _dotDecimalToCents(opening[1]!);

    for (final block in blocks) {
      final month = int.parse(block.date[1]!);
      final day = int.parse(block.date[2]!);
      final body = squash([block.date[5] ?? '', ...block.lines].join(' '));
      if (body.isEmpty) {
        warn(ParseWarning(bankId, 'Date line with no movement body', fields: {'date': '$day/$month'}));
        continue;
      }

      final resolved = _resolve(body, balance);
      if (resolved.length != 1) {
        final splits = _splits(body);
        // The amount/balance text is never reported: the payee is the
        // description without the numbers at the end.
        final description = splits.isNotEmpty ? splits.first.description : body.replaceFirst(RegExp(r'[\d  .]+$'), '');
        warn(
          ParseWarning(
            bankId,
            'Could not resolve amount/balance against the running balance; skipping',
            fields: {'date': '$day/$month', 'candidates': resolved.length},
            payee: _cleanPayee(description),
          ),
        );
        // Re-sync the chain if the row's balance is unambiguous anyway, so
        // one bad row doesn't break every later one.
        final balances = splits.map((s) => s.balance).toSet();
        if (balances.length == 1) balance = balances.single;
        continue;
      }

      final split = resolved.single;
      balance = split.balance;
      // A month before the period's first month is in the following year
      // (a December -> January statement).
      final year = month < startMonth ? startYear + 1 : startYear;
      transactions.add(
        RawTransaction(
          date: '$year-${pad2(month)}-${pad2(day)}',
          payee: _cleanPayee(split.description),
          amountCents: split.amountCents,
          rawLine: squash([block.dateLine, ...block.lines].join(' ')),
        ),
      );
    }

    return transactions;
  }

  /// "34.99" / "1 386.35" -> cents. The dot is the *decimal* separator.
  static int _dotDecimalToCents(String raw) {
    final value = double.parse(raw.replaceAll(RegExp(r'[  ]'), ''));
    return (value * 100).round();
  }

  static String _cleanPayee(String rawPayee) {
    // Trailing bank references ("31543417061 PT41100946") differ per
    // transaction and would defeat the category memory.
    var payee = rawPayee.replaceFirst(RegExp(r'\s+\d{6,}(?:\s+[A-Z0-9]+)*$'), '').trim();
    payee = stripFirstPrefix(payee, _noisePrefixes);
    return squash(payee);
  }

  /// Every way to read the end of [body] as `description amount balance`.
  ///
  /// The balance runs to the end of the text. The amount sits right before
  /// it, either glued on (pdf.js: "34.99265.16") or after one space
  /// (PDFium: "34.99 265.16"), and starts the text or follows a space.
  /// Thousands are space-separated, so "1 386.35 1 399.60" has several
  /// readings; only the running balance can pick one.
  static List<_Split> _splits(String body) {
    final splits = <_Split>[];
    for (var b = 1; b < body.length; b++) {
      if (!_amountOnly.hasMatch(body.substring(b))) continue;
      final balance = _dotDecimalToCents(body.substring(b));
      final amountEnd = body[b - 1] == ' ' ? b - 1 : b;
      for (var a = 0; a < amountEnd; a++) {
        if (a > 0 && body[a - 1] != ' ') continue;
        final amountText = body.substring(a, amountEnd);
        if (!_amountOnly.hasMatch(amountText)) continue;
        splits.add(
          _Split(
            description: body.substring(0, a).trim(),
            amountCents: _dotDecimalToCents(amountText),
            balance: balance,
          ),
        );
      }
    }
    return splits;
  }

  /// The splits that reconcile against [previous]: the sign comes from
  /// whether the balance went down (debit) or up (credit).
  static List<_Split> _resolve(String body, int previous) {
    final resolved = <_Split>[];
    for (final s in _splits(body)) {
      if (previous - s.amountCents == s.balance) {
        resolved.add(_Split(description: s.description, amountCents: -s.amountCents, balance: s.balance));
      } else if (previous + s.amountCents == s.balance) {
        resolved.add(s);
      }
    }
    return resolved;
  }
}

class _Split {
  final String description;
  final int amountCents;
  final int balance;

  const _Split({required this.description, required this.amountCents, required this.balance});
}
