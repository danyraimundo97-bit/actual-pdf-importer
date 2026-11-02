import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/account_page.dart';
import '../../data/providers.dart';

/// One account's transactions, loaded a page at a time as the list scrolls.
class AccountPageState {
  final String? name;
  final int? balanceCents;
  final List<AccountTransaction> rows;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final Object? error;

  const AccountPageState({
    this.name,
    this.balanceCents,
    this.rows = const [],
    this.nextCursor,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;
}

class AccountPageController extends AutoDisposeFamilyNotifier<AccountPageState, String> {
  static const pageSize = 50;

  @override
  AccountPageState build(String accountId) {
    Future.microtask(refresh);
    return const AccountPageState();
  }

  String? get _budgetSyncId => ref.read(appConfigProvider).budgetSyncId;

  /// Reloads from the newest transaction.
  Future<void> refresh() async {
    state = AccountPageState(name: state.name, balanceCents: state.balanceCents, rows: state.rows, loading: true);
    try {
      final page = await ref
          .read(importerApiProvider)
          .getAccountPage(arg, budgetSyncId: _budgetSyncId, limit: pageSize);
      state = AccountPageState(
        name: page.accountName,
        balanceCents: page.balanceCents,
        rows: page.transactions,
        nextCursor: page.nextCursor,
        loading: false,
      );
    } on ApiException catch (e) {
      state = AccountPageState(name: state.name, rows: state.rows, loading: false, error: e);
    }
  }

  /// The next page, if there is one and none is loading.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.loading) return;
    state = AccountPageState(
      name: state.name,
      balanceCents: state.balanceCents,
      rows: state.rows,
      nextCursor: cursor,
      loading: false,
      loadingMore: true,
    );
    try {
      final page = await ref
          .read(importerApiProvider)
          .getAccountPage(arg, budgetSyncId: _budgetSyncId, before: cursor, limit: pageSize);
      state = AccountPageState(
        name: page.accountName,
        balanceCents: page.balanceCents,
        rows: [...state.rows, ...page.transactions],
        nextCursor: page.nextCursor,
        loading: false,
      );
    } on ApiException catch (e) {
      // The cursor is unknown when the list changed meanwhile: start over.
      if (e.code == 'INVALID_FIELD') return refresh();
      state = AccountPageState(
        name: state.name,
        balanceCents: state.balanceCents,
        rows: state.rows,
        nextCursor: cursor,
        loading: false,
        error: e,
      );
    }
  }
}

final accountPageProvider =
    AutoDisposeNotifierProviderFamily<AccountPageController, AccountPageState, String>(AccountPageController.new);
