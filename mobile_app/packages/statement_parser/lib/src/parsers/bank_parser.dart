import '../types.dart';

/// One bank's statement reader. Port of `BankParser` in `backend_app/src/types.ts`
/// (the AI parser stays on the backend).
abstract class BankParser {
  String get bankId;

  /// Cheap content sniff: does this text look like this bank's statement?
  /// Never by file name: statements get renamed and forwarded.
  bool canParse(String fullText);

  /// Reads every movement it can. Rows it can't read are skipped and
  /// reported to [warn], never thrown.
  List<RawTransaction> parse(String fullText, WarningSink warn);
}
