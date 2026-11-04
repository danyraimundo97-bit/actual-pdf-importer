import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../core/log/app_log.dart';
import 'local/ledger_sync.dart';
import 'providers.dart';

const _log = AppLog('ledger');

class LedgerSyncStatus {
  final bool running;

  /// The last successful pull of the current budget, or null.
  final DateTime? lastPulledAt;

  /// The last run's failure, for the status line; null after a success.
  final String? error;

  const LedgerSyncStatus({this.running = false, this.lastPulledAt, this.error});
}

/// Runs [LedgerSync] for the connected budget, one run at a time
/// (docs/plans/local-ledger.md, Phase 5). Triggered like the category sync:
/// on start and connection changes (AppShell), after an import or a quick
/// add ([request]), and by pull-to-refresh ([syncNow]). Without Actual it
/// does nothing: the phone's own budget has nothing to sync with yet.
class LedgerSyncController extends Notifier<LedgerSyncStatus> {
  Timer? _debounce;
  Future<void>? _run;
  bool _again = false;

  /// What the last failed run threw, so [ensurePulled] can hand the screen
  /// the real error (an ApiException shows its message).
  Object? _lastFailure;

  @override
  LedgerSyncStatus build() {
    ref.onDispose(() => _debounce?.cancel());
    return const LedgerSyncStatus();
  }

  LedgerSync _sync() => LedgerSync(
    ref.read(appDatabaseProvider),
    (budgetSyncId, epoch, lastId) =>
        ref.read(ledgerApiProvider).pull(budgetSyncId: budgetSyncId, epoch: epoch, lastId: lastId),
  );

  void request({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  /// Pulls now, or once more after the run in progress. Never throws; the
  /// outcome is in [state].
  Future<void> syncNow() async {
    _debounce?.cancel();
    if (_run != null) {
      _again = true;
      return _run;
    }
    final scope = await _connectedScope();
    if (scope == null) return;
    final run = _pull(scope);
    _run = run;
    try {
      await run;
    } finally {
      _run = null;
      if (_again) {
        _again = false;
        request(delay: Duration.zero);
      }
    }
  }

  /// Makes sure [scope] has been pulled once, so a screen never shows an
  /// empty copy as if the budget were empty. Throws when that first pull
  /// fails (the screen shows the error and a retry).
  Future<void> ensurePulled(String scope) async {
    if (await _sync().lastPulledAt(scope) != null) return;
    await syncNow();
    if (await _sync().lastPulledAt(scope) == null) {
      throw _lastFailure ?? StateError('No copy of the budget yet');
    }
  }

  Future<void> _pull(String scope) async {
    state = LedgerSyncStatus(running: true, lastPulledAt: state.lastPulledAt ?? await _sync().lastPulledAt(scope));
    _lastFailure = null;
    try {
      await _sync().pull(scope);
      state = LedgerSyncStatus(lastPulledAt: await _sync().lastPulledAt(scope));
    } on ApiException catch (e) {
      _lastFailure = e;
      _log.warn('Ledger pull failed', {'code': e.code, 'status': e.statusCode});
      state = LedgerSyncStatus(lastPulledAt: await _sync().lastPulledAt(scope), error: e.message);
    } catch (e, st) {
      _lastFailure = e;
      _log.error('Ledger pull crashed', e, st);
      state = LedgerSyncStatus(
        lastPulledAt: await _sync().lastPulledAt(scope),
        error: 'Something went wrong. See Diagnostics.',
      );
    }
  }

  /// The connected budget's sync id, or null without Actual.
  Future<String?> _connectedScope() async {
    final link = ref.listen(linkStateProvider.future, (_, _) {});
    try {
      if (await link.read() != LinkState.ready) return null;
      return ref.read(appConfigProvider).budgetSyncId;
    } catch (_) {
      return null;
    } finally {
      link.close();
    }
  }
}

final ledgerSyncProvider = NotifierProvider<LedgerSyncController, LedgerSyncStatus>(LedgerSyncController.new);
