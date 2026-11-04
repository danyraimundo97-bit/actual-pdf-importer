import '../../../data/models/actual_account.dart';
import '../../../data/models/parse_result.dart';

/// Passed via go_router's `extra` when pushing '/review' — see
/// core/router.dart and features/import/screens/import_screen.dart.
class ReviewScreenArgs {
  final ParseResult parseResult;

  /// Null when there's no Actual account to import into (Actual not
  /// connected, or no backend): Review then offers CSV export only.
  final ActualAccount? account;
  final String? budgetSyncId;

  /// Actual isn't connected: Review saves into one of the phone's own
  /// accounts (the local ledger), chosen there, instead of offering only
  /// CSV export.
  final bool saveOnPhone;

  const ReviewScreenArgs({required this.parseResult, this.account, this.budgetSyncId, this.saveOnPhone = false});
}
