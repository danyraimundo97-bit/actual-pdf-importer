/// Reads bank statement text into transactions, on the device.
///
/// A pure Dart port of the backend's local parsers (`backend_app/src/parsers`),
/// with the same dedupe ids. Text extraction from the PDF is the app's job;
/// this package only reads text.
library;

export 'src/imported_id.dart' show assignImportedIds, importedIdPrefix;
export 'src/parsers/activobank.dart' show ActivoBankParser;
export 'src/parsers/bank_parser.dart' show BankParser;
export 'src/parsers/moey.dart' show MoeyParser;
export 'src/parsers/traderepublic.dart' show TradeRepublicParser;
export 'src/statement_parser.dart';
export 'src/types.dart' show ParseWarning, RawTransaction, WarningSink, parsePtAmountToCents, normalizePtDate;
