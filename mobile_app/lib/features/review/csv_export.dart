import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/parsed_transaction.dart';

/// The way out without Actual (docs/plans/dart-parser.md, Phase 5): the
/// reviewed lines as a CSV that Actual's web app (or a spreadsheet) can
/// import, mapping the columns by their header.
///
/// `amount` is a plain decimal with a dot and a minus for outflows, never
/// a formatted figure, so every importer reads it the same way. `category`
/// is the chosen category's name.
String transactionsToCsv(Iterable<ParsedTransaction> transactions) {
  final out = StringBuffer('date,payee,amount,category\r\n');
  for (final t in transactions) {
    out
      ..write(_isoDate(t.date))
      ..write(',')
      ..write(_field(t.payee))
      ..write(',')
      ..write(centsToDecimal(t.amountCents))
      ..write(',')
      ..write(_field(t.effectiveCategoryName ?? ''))
      ..write('\r\n');
  }
  return out.toString();
}

/// UTF-8 with a byte order mark, so spreadsheet apps don't misread accents.
Uint8List csvBytes(String csv) => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

/// `-1230` → `-12.30`. Integer arithmetic: money is never a double here.
String centsToDecimal(int cents) {
  final abs = cents.abs();
  return '${cents < 0 ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

/// RFC 4180: quote a field holding a comma, quote or line break, doubling
/// any quotes inside.
String _field(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
