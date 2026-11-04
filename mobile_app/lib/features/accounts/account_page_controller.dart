import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/log/app_log.dart';
import '../../data/models/account_page.dart';
import '../../data/providers.dart';

const _log = AppLog('accounts');

/// One account's transactions, loaded a page at a time as the list scrolls.
class AccountPageState {
  final String? name;
  final int? balanceCents;
  final List<AccountTransaction> rows;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final Object? error;

  /// Read from the phone's own ledger (Actual not connected): rows can be
  /// edited and removed here.
  final bool onPhone;

  const AccountPageState({
    this.name,
    this.balanceCents,
    this.rows = const [],
    this.nextCursor,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.onPhone = false,
  });

  bool get hasMore => nextCursor != null;
}

class AccountPageController extends AutoDisposeFamilyNotifier<AccountPageState, String> {
  static const pageSize = 50;

  @override
  AccountPageState build(String accountId) {
    // The rows change under the screen (an edit here, a statement saved,
    // a sync): reload from the top.
    ref.listen(ledgerChangesProvider, (_, _) => refresh());
    Future.microtask(refresh);
    return const AccountPageState();
  }

  /// Always the ledger: the phone's own account, or the copy of an Actual
  /// one (kept by the sync, Phase 5).
  Future<AccountPage> _page({String? before}) =>
      ref.read(ledgerReportsProvider).accountPage(arg, before: before, limit: pageSize);

  /// Reloads from the newest transaction.
  Future<void> refresh() async {
    state = AccountPageState(
      name: state.name,
      balanceCents: state.balanceCents,
      rows: state.rows,
      loading: true,
      onPhone: state.onPhone,
    );
    try {
      final onPhone = await ref.read(readsLedgerProvider.future);
      final page = await _page();
      state = AccountPageState(
        name: page.accountName,
        balanceCents: page.balanceCents,
        rows: page.transactions,
        nextCursor: page.nextCursor,
        loading: false,
        onPhone: onPhone,
      );
    } on ApiException catch (e) {
      state = AccountPageState(name: state.name, rows: state.rows, loading: false, error: e);
    } catch (e, stack) {
      _log.error('Account could not be read', e, stack, {'account': arg});
      state = AccountPageState(name: state.name, rows: state.rows, loading: false, error: e, onPhone: state.onPhone);
    }
  }

  /// The next page, if there is one and none is loading.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.loading) return;
    final onPhone = state.onPhone;
    state = AccountPageState(
      name: state.name,
      balanceCents: state.balanceCents,
      rows: state.rows,
      nextCursor: cursor,
      loading: false,
      loadingMore: true,
      onPhone: onPhone,
    );
    try {
      final page = await _page(before: cursor);
      state = AccountPageState(
        name: page.accountName,
        balanceCents: page.balanceCents,
        rows: [...state.rows, ...page.transactions],
        nextCursor: page.nextCursor,
        loading: false,
        onPhone: onPhone,
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

final accountPageProvider = AutoDisposeNotifierProviderFamily<AccountPageController, AccountPageState, String>(
  AccountPageController.new,
);
