import 'parsed_transaction.dart';

class ParseResult {
  final String bankId;
  final List<ParsedTransaction> transactions;

  /// The suggested categories are the app's own (Actual wasn't connected
  /// when the statement was read), not Actual's. They mustn't reach
  /// `/import/confirm`: Review drops them when importing into Actual.
  final bool localCategories;

  const ParseResult({required this.bankId, required this.transactions, this.localCategories = false});

  factory ParseResult.fromJson(Map<String, dynamic> json) {
    final rawList = (json['transactions'] as List).cast<Map<String, dynamic>>();
    return ParseResult(
      bankId: json['bankId'] as String,
      transactions: rawList.map(ParsedTransaction.fromJson).toList(),
    );
  }
}
