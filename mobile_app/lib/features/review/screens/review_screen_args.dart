import '../../../data/models/actual_account.dart';
import '../../../data/models/parse_result.dart';

/// Passed via go_router's `extra` when pushing '/review' — see
/// core/router.dart and features/import/screens/import_screen.dart.
class ReviewScreenArgs {
  final ParseResult parseResult;
  final ActualAccount account;
  final String? budgetSyncId;

  const ReviewScreenArgs({
    required this.parseResult,
    required this.account,
    this.budgetSyncId,
  });
}
