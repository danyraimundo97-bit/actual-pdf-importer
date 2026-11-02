import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/api/api_client.dart';
import '../../data/api/importer_api.dart';
import '../../data/models/actual_budget.dart';
import '../../data/models/backend_config.dart';
import '../../data/providers.dart';
import '../../shared/widgets/labeled_field.dart';
import '../../core/log/app_log.dart';

enum ConnectionStatus { idle, testing, connected, failed }

/// Shown when the importer and Actual are both reachable but Actual has no
/// budget to import into — common on a freshly set-up Actual server.
const noBudgetsMessage =
    "Your Actual server doesn't have any budgets yet. Open Actual in your browser, "
    'create a budget (or import one), then tap Refresh.';

/// Connection + budget selection state shared by Settings and the setup
/// guide, so both run the exact same checks.
class ConnectionCheck {
  final ConnectionStatus status;
  final String? message;
  final BackendConfig? config;
  final List<ActualBudget> budgets;
  final bool loadingBudgets;
  final String? budgetsError;

  const ConnectionCheck({
    this.status = ConnectionStatus.idle,
    this.message,
    this.config,
    this.budgets = const [],
    this.loadingBudgets = false,
    this.budgetsError,
  });

  bool get isConnected => status == ConnectionStatus.connected;

  ConnectionCheck copyWith({
    ConnectionStatus? status,
    String? message,
    BackendConfig? config,
    List<ActualBudget>? budgets,
    bool? loadingBudgets,
    String? budgetsError,
    bool clearMessage = false,
    bool clearBudgetsError = false,
  }) {
    return ConnectionCheck(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      config: config ?? this.config,
      budgets: budgets ?? this.budgets,
      loadingBudgets: loadingBudgets ?? this.loadingBudgets,
      budgetsError: clearBudgetsError ? null : (budgetsError ?? this.budgetsError),
    );
  }
}

class ConnectionController extends AutoDisposeNotifier<ConnectionCheck> {
  @override
  ConnectionCheck build() => const ConnectionCheck();

  /// Saves the address and token, then checks /health and /config. Returns
  /// whether the importer is reachable and accepted the token.
  Future<bool> saveAndTest({required String url, required String token}) async {
    if (url.trim().isEmpty) {
      state = state.copyWith(
        status: ConnectionStatus.failed,
        message: 'Enter the address of your importer backend first.',
      );
      return false;
    }
    final normalized = normalizeBackendUrl(url);
    if (normalized == null) {
      state = state.copyWith(
        status: ConnectionStatus.failed,
        message: 'That is not a valid address. Use something like http://192.168.1.10:3000.',
      );
      return false;
    }
    await ref.read(appConfigProvider.notifier).setBackendUrl(normalized);
    await ref.read(secretStoreProvider).setApiToken(token.trim());
    return test();
  }

  Future<bool> test() async {
    state = state.copyWith(status: ConnectionStatus.testing, clearMessage: true);
    final api = ref.read(importerApiProvider);
    try {
      final health = await api.health();
      if (health != HealthStatus.ok) {
        _log.warn('Connection test failed', {'health': health.name});
        state = state.copyWith(
          status: ConnectionStatus.failed,
          message: health == HealthStatus.notImporter
              ? notImporterMessage
              : 'Could not reach the importer at this address. Check that backend_app '
                    'is running and the phone is on the same network.',
        );
        return false;
      }
      final config = await api.getConfig();
      _log.info('Connection test passed', {'parserMode': config.parserMode, 'ai': config.usesAi});
      state = state.copyWith(
        status: ConnectionStatus.connected,
        config: config,
        message:
            'Connected. Parser mode: ${config.parserMode}'
            '${config.usesAi ? ', using ${config.aiProvider}' : ''}.',
      );
      return true;
    } on ApiException catch (e) {
      _log.warn('Connection test failed', {'code': e.code, 'status': e.statusCode});
      state = state.copyWith(
        status: ConnectionStatus.failed,
        message: e.isUnauthorized
            ? 'The importer is reachable, but it rejected the access token.'
            : e.message,
      );
      return false;
    }
  }

  Future<void> loadBudgets() async {
    state = state.copyWith(loadingBudgets: true, clearBudgetsError: true);
    try {
      final budgets = await ref.read(importerApiProvider).getBudgets();
      _log.info('Budgets loaded', {'count': budgets.length});
      state = state.copyWith(budgets: budgets, loadingBudgets: false);
    } on ApiException catch (e) {
      state = state.copyWith(loadingBudgets: false, budgetsError: e.message);
    }
  }

  /// Makes [budget] the active one. Encrypted budgets need [password]
  /// (asked for by the caller, see [promptBudgetPassword]).
  Future<void> selectBudget(ActualBudget budget, {String? password}) async {
    if (password != null) {
      await ref.read(secretStoreProvider).setBudgetPassword(budget.syncId, password);
    }
    await ref.read(appConfigProvider.notifier).setBudget(budget.syncId, budget.name);
    _log.info('Budget selected', {'budgetSyncId': budget.syncId, 'encrypted': password != null});
  }
}

const _log = AppLog('connection');

final connectionControllerProvider =
    AutoDisposeNotifierProvider<ConnectionController, ConnectionCheck>(ConnectionController.new);

Future<String?> promptBudgetPassword(BuildContext context, ActualBudget budget) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Unlock "${budget.name}"'),
      content: LabeledField(
        label: 'Budget password',
        helper: "Actual's end-to-end encryption password, not a statement password.",
        child: TextField(controller: controller, obscureText: true, autofocus: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Unlock'),
        ),
      ],
    ),
  );
}

/// Selects [budget], asking for its password first if it is encrypted.
/// Returns false if the user cancelled the password prompt.
Future<bool> chooseBudget(BuildContext context, WidgetRef ref, ActualBudget budget) async {
  String? password;
  if (budget.encrypted) {
    password = await promptBudgetPassword(context, budget);
    if (password == null) return false;
  }
  await ref.read(connectionControllerProvider.notifier).selectBudget(budget, password: password);
  return true;
}
