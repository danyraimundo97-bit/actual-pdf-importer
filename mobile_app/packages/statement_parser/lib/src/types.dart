/// One movement read from a statement. Port of `RawTransaction` in
/// `backend_app/src/types.ts`.
class RawTransaction {
  /// `YYYY-MM-DD`.
  final String date;

  /// Cleaned merchant/description: what the category memory is keyed on.
  final String payee;

  /// Integer cents, negative = money out.
  final int amountCents;

  /// The statement text this movement was read from, for the review screen
  /// and Actual's notes. Never logged: it carries the amount.
  final String rawLine;

  const RawTransaction({required this.date, required this.payee, required this.amountCents, required this.rawLine});

  @override
  String toString() => 'RawTransaction($date, $payee, $amountCents)';
}

/// Something a parser skipped or couldn't read. Never fatal: a statement
/// with one unreadable row still yields the others, and the warning says
/// which one was dropped.
///
/// [fields] never holds amounts or balances. A payee, when known, is kept
/// apart in [payee] so the app can log it at debug level only.
class ParseWarning {
  final String bankId;
  final String message;
  final Map<String, Object?> fields;
  final String? payee;

  const ParseWarning(this.bankId, this.message, {this.fields = const {}, this.payee});

  @override
  String toString() => '[$bankId] $message $fields';
}

/// Collects a parser's warnings.
typedef WarningSink = void Function(ParseWarning warning);

/// Converts a Portuguese-formatted amount ("1.234,56" or "-12,30") into
/// integer cents. Throws on unparseable input rather than returning 0: a
/// silent 0 is worse than a loud failure in financial data.
int parsePtAmountToCents(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'\s'), '');
  final negative = cleaned.startsWith('-');
  final digits = cleaned.replaceFirst(RegExp(r'^-'), '').replaceAll('.', '').replaceFirst(',', '.');
  final value = double.tryParse(digits);
  if (value == null || !RegExp(r'^\d+(\.\d+)?$').hasMatch(digits)) {
    throw FormatException('Could not parse amount');
  }
  final cents = (value * 100).round();
  return negative ? -cents : cents;
}

/// Converts "DD-MM-YYYY" or "DD/MM/YYYY" to "YYYY-MM-DD".
String normalizePtDate(String raw) {
  final match = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$').firstMatch(raw.trim());
  if (match == null) throw FormatException('Could not parse date');
  return '${match[3]}-${match[2]}-${match[1]}';
}

/// Collapses every whitespace run to one space and trims.
String squash(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Strips only the first of [prefixes] that matches, so longer, more
/// specific prefixes must come first.
String stripFirstPrefix(String text, List<RegExp> prefixes) {
  for (final prefix in prefixes) {
    final stripped = text.replaceFirst(prefix, '');
    if (stripped != text) return stripped.trim();
  }
  return text;
}

String pad2(int n) => n.toString().padLeft(2, '0');
