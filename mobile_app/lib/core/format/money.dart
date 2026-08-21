import 'package:intl/intl.dart';

final NumberFormat _formatter = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);

/// Formats integer cents as "−42,37 €" / "+42,37 €" — the sign is always
/// explicit (never colour alone), using a true minus sign rather than a
/// hyphen for outflows.
String formatCents(int cents) {
  final formatted = _formatter.format(cents.abs() / 100);
  return cents < 0 ? '−$formatted' : '+$formatted';
}
