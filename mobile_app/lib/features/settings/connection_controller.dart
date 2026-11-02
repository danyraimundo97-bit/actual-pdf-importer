import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/api/api_client.dart';
import '../../data/api/importer_api.dart';
import '../../data/models/actual_budget.dart';
import '../../data/models/actual_connection.dart';
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

  /// The backend's link to Actual, once the backend has answered.
  final ActualConnection? actual;
  final ConnectionStatus actualStatus;
  final String? actualMessage;

  /// The backend's error code for the last failed Actual connect.
  final String? actualErrorCode;

  const ConnectionCheck({
    this.status = ConnectionStatus.idle,
    this.message,
    this.config,
    this.budgets = const [],
    this.loadingBudgets = false,
    this.budgetsError,
    this.actual,
    this.actualStatus = ConnectionStatus.idle,
    this.actualMessage,
    this.actualErrorCode,
  });

  /// The backend answered and accepted the token.
  bool get isConnected => status == ConnectionStatus.connected;

  /// ...and it has an Actual server.
  bool get actualConfigured => isConnected && (actual?.configured ?? config?.actualConfigured ?? false);

  ConnectionCheck copyWith({
    ConnectionStatus? status,
    String? message,
    BackendConfig? config,
    List<ActualBudget>? budgets,
    bool? loadingBudgets,
    String? budgetsError,
    ActualConnection? actual,
    ConnectionStatus? actualStatus,
    String? actualMessage,
    String? actualErrorCode,
    bool clearMessage = false,
    bool clearBudgetsError = false,
    bool clearActualMessage = false,
  }) {
    return ConnectionCheck(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      config: config ?? this.config,
      budgets: budgets ?? this.budgets,
      loadingBudgets: loadingBudgets ?? this.loadingBudgets,
      budgetsError: clearBudgetsError ? null : (budgetsError ?? this.budgetsError),
      actual: actual ?? this.actual,
      actualStatus: actualStatus ?? this.actualStatus,
      actualMessage: clearActualMessage ? null : (actualMessage ?? this.actualMessage),
      actualErrorCode: clearActualMessage ? null : (actualErrorCode ?? this.actualErrorCode),
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
      _log.info('Connection test passed', {
        'parserMode': config.parserMode,
        'ai': config.usesAi,
        'actual': config.actualConfigured,
      });
      state = state.copyWith(
        status: ConnectionStatus.connected,
        config: config,
        actualStatus: config.actualConfigured ? ConnectionStatus.connected : ConnectionStatus.idle,
        message:
            'Connected. Parser mode: ${config.parserMode}'
            '${config.usesAi ? ', using ${config.aiProvider}' : ''}.',
      );
      await loadActual();
      ref.invalidate(backendConfigProvider);
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

  /// GET /actual/connection. Older backends don't have it: they always had
  /// an Actual server, so that's assumed.
  Future<void> loadActual() async {
    try {
      final actual = await ref.read(importerApiProvider).getActualConnection();
      state = state.copyWith(
        actual: actual,
        actualStatus: actual.configured ? ConnectionStatus.connected : ConnectionStatus.idle,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        state = state.copyWith(
          actual: const ActualConnection(configured: true, locked: true),
          actualStatus: ConnectionStatus.connected,
        );
      }
    }
  }

  /// Points the backend at an Actual server. The backend checks it first
  /// and keeps the old one if this one doesn't work.
  Future<bool> connectActual({required String serverUrl, required String password}) async {
    if (serverUrl.trim().isEmpty) {
      state = state.copyWith(
        actualStatus: ConnectionStatus.failed,
        actualMessage: "Enter your Actual server's address first.",
        actualErrorCode: 'INVALID_FIELD',
      );
      return false;
    }
    state = state.copyWith(actualStatus: ConnectionStatus.testing, clearActualMessage: true);
    try {
      final actual = await ref.read(importerApiProvider).connectActual(serverUrl: serverUrl.trim(), password: password);
      _log.info('Actual server connected', {'serverVersion': actual.serverVersion});
      state = state.copyWith(
        actual: actual,
        actualStatus: ConnectionStatus.connected,
        actualMessage: actual.serverVersion == null
            ? 'Connected to Actual.'
            : 'Connected to Actual ${actual.serverVersion}.',
      );
      ref.invalidate(backendConfigProvider);
      await loadBudgets();
      return true;
    } on ApiException catch (e) {
      _log.warn('Actual connection failed', {'code': e.code, 'status': e.statusCode});
      state = state.copyWith(
        actualStatus: ConnectionStatus.failed,
        actualMessage: actualErrorMessage(e),
        actualErrorCode: e.code,
      );
      return false;
    }
  }

  /// Unlinks the backend from Actual; it keeps running without one.
  Future<void> disconnectActual() async {
    try {
      final actual = await ref.read(importerApiProvider).disconnectActual();
      _log.info('Actual server disconnected');
      state = state.copyWith(
        actual: actual,
        actualStatus: ConnectionStatus.idle,
        budgets: const [],
        clearActualMessage: true,
      );
      ref.invalidate(backendConfigProvider);
    } on ApiException catch (e) {
      state = state.copyWith(actualStatus: ConnectionStatus.failed, actualMessage: actualErrorMessage(e), actualErrorCode: e.code);
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

/// What to tell the user for each way connecting to Actual can fail.
String actualErrorMessage(ApiException e) => switch (e.code) {
      'ACTUAL_UNREACHABLE' =>
        "Couldn't reach Actual at that address. Check the address and that the backend can reach it "
            "(in Docker, use the server's network address, not localhost).",
      'ACTUAL_AUTH_FAILED' => 'Actual rejected the password. Use the password you log in to Actual with.',
      'ACTUAL_VERSION_TOO_OLD' => e.message,
      'AUTH_REQUIRED' =>
        'The backend has no access token set, so it won\'t let the app change its Actual server. '
            'Set IMPORT_TOKEN in the backend\'s .env, restart it, and enter the same token here.',
      'CONNECTION_LOCKED' => "The Actual server is set in the backend's .env, so it can only be changed there.",
      _ => e.message,
    };

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
