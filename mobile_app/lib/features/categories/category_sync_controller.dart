import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/log/app_log.dart';
import '../../data/local/db/category_sync.dart';
import '../../data/providers.dart';

const _log = AppLog('categories');

enum CategorySyncPhase { idle, running, done, failed }

class CategorySyncStatus {
  final CategorySyncPhase phase;
  final CategorySyncResult? result;
  final String? error;
  const CategorySyncStatus(this.phase, {this.result, this.error});
}

/// Runs [CategorySync] one at a time. [request] debounces bursts of edits;
/// [syncNow] runs right away (or once more after the current run). Without
/// a backend it does nothing: the phone's data simply stays on the phone.
class CategorySyncController extends Notifier<CategorySyncStatus> {
  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  CategorySyncStatus build() {
    ref.onDispose(() => _debounce?.cancel());
    return const CategorySyncStatus(CategorySyncPhase.idle);
  }

  void request({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  Future<CategorySyncStatus> syncNow() async {
    _debounce?.cancel();
    final config = ref.read(appConfigProvider);
    if (config.backendUrl?.isNotEmpty != true) return state;
    if (_running) {
      _again = true;
      return state;
    }
    _running = true;
    state = const CategorySyncStatus(CategorySyncPhase.running);
    try {
      final result = await CategorySync(
        ref.read(appDatabaseProvider),
        ref.read(categoriesApiProvider),
        ref.read(importerApiProvider),
        ref.read(settingsStoreProvider),
      ).run(budgetSyncId: config.budgetSyncId, actualReady: await _actualReady());
      _log.info('Categories synced', {'sent': result.sent, 'received': result.received});
      // Screens showing categories reload; that bump asks for another sync,
      // which finds nothing new and stops there.
      if (result.received > 0) ref.read(categoryMemoryRevisionProvider.notifier).state++;
      state = CategorySyncStatus(CategorySyncPhase.done, result: result);
    } on ApiException catch (e) {
      _log.warn('Category sync failed', {'code': e.code, 'status': e.statusCode});
      state = CategorySyncStatus(CategorySyncPhase.failed, error: e.message);
    } catch (e, st) {
      _log.error('Category sync crashed', e, st);
      state = const CategorySyncStatus(CategorySyncPhase.failed, error: 'Something went wrong. See Diagnostics.');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        request();
      }
    }
    return state;
  }

  Future<bool> _actualReady() async {
    final link = ref.listen(linkStateProvider.future, (_, _) {});
    try {
      return await link.read() == LinkState.ready;
    } catch (_) {
      return false;
    } finally {
      link.close();
    }
  }
}

final categorySyncProvider = NotifierProvider<CategorySyncController, CategorySyncStatus>(
  CategorySyncController.new,
);
