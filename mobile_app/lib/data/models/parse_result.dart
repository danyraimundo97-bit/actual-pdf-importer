import 'parsed_transaction.dart';

class ParseResult {
  final String bankId;
  final List<ParsedTransaction> transactions;

  const ParseResult({required this.bankId, required this.transactions});

  factory ParseResult.fromJson(Map<String, dynamic> json) {
    final rawList = (json['transactions'] as List).cast<Map<String, dynamic>>();
    return ParseResult(
      bankId: json['bankId'] as String,
      transactions: rawList.map(ParsedTransaction.fromJson).toList(),
    );
  }
}
