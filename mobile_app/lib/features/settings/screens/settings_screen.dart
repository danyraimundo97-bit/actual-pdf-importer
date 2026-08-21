import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../data/models/actual_budget.dart';
import '../../../data/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  bool _testing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  List<ActualBudget> _budgets = [];
  bool _loadingBudgets = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    _urlController = TextEditingController(text: config.backendUrl ?? '');
    _tokenController = TextEditingController();
    ref.read(secretStoreProvider).apiToken.then((token) {
      if (mounted && token != null) {
        setState(() => _tokenController.text = token);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await ref.read(appConfigProvider.notifier).setBackendUrl(url);
    await ref.read(secretStoreProvider).setApiToken(_tokenController.text.trim());
    await _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    final api = ref.read(importerApiProvider);
    try {
      final healthy = await api.health();
      if (!healthy) {
        setState(() {
          _statusIsError = true;
          _statusMessage = 'Could not reach the importer at this address.';
        });
        return;
      }
      final config = await api.getConfig();
      setState(() {
        _statusIsError = false;
        _statusMessage = 'Connected — parser mode: ${config.parserMode}'
            '${config.usesAi ? ', AI: ${config.aiProvider}' : ''}.';
      });
      await _loadBudgets();
    } on ApiException catch (e) {
      setState(() {
        _statusIsError = true;
        _statusMessage = e.isUnauthorized ? 'Connected, but the token was rejected.' : e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _loadBudgets() async {
    setState(() => _loadingBudgets = true);
    try {
      final budgets = await ref.read(importerApiProvider).getBudgets();
      if (mounted) setState(() => _budgets = budgets);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingBudgets = false);
    }
  }

  Future<void> _selectBudget(ActualBudget budget) async {
    if (budget.encrypted) {
      final password = await _promptBudgetPassword(budget);
      if (password == null) return;
      await ref.read(secretStoreProvider).setBudgetPassword(budget.syncId, password);
    }
    await ref.read(appConfigProvider.notifier).setBudget(budget.syncId, budget.name);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Budget set to "${budget.name}".')));
    }
  }

  Future<String?> _promptBudgetPassword(ActualBudget budget) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${budget.name}" is encrypted'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Budget password',
            helperText: "Actual's own end-to-end encryption — not a statement password.",
          ),
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

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Backend connection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              hintText: 'http://192.168.1.10:3000',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(labelText: 'API token (X-Import-Token)'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _testing ? null : _save,
            child: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save & test connection'),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusIsError
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_statusMessage!),
            ),
          ],
          const Divider(height: 32),
          Text('Budget', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (config.budgetName != null) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Current: ${config.budgetName}'),
          ),
          if (_loadingBudgets)
            const Center(child: CircularProgressIndicator())
          else if (_budgets.isEmpty)
            const Text('Test the connection above to load budgets.')
          else
            ..._budgets.map(
              (b) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(b.encrypted ? Icons.lock_outline : Icons.folder_open),
                title: Text(b.name),
                trailing: b.syncId == config.budgetSyncId
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => _selectBudget(b),
              ),
            ),
          const Divider(height: 32),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'PDFs are sent only to the backend address above; nothing reaches any cloud '
            'service unless the parser mode shown here is "ai" or "both".',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(secretStoreProvider).forgetAllPdfPasswords();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Forgot all saved statement passwords.')),
                );
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Forget saved statement passwords'),
          ),
        ],
      ),
    );
  }
}
