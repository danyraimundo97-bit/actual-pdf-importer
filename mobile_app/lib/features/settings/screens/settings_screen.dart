import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_budget.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/inline_note.dart';
import '../connection_controller.dart';
import '../widgets/actual_server_card.dart';
import '../widgets/connection_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

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
    // Check the saved connection right away, so the Actual server and the
    // budgets show their real state without pressing "Save and test".
    if (config.backendUrl != null && config.backendUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    final controller = ref.read(connectionControllerProvider.notifier);
    if (await controller.test() && ref.read(connectionControllerProvider).actualConfigured) {
      await controller.loadBudgets();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(connectionControllerProvider.notifier);
    final ok = await controller.saveAndTest(url: _urlController.text, token: _tokenController.text);
    if (ok && ref.read(connectionControllerProvider).actualConfigured) await controller.loadBudgets();
  }

  Future<void> _selectBudget(ActualBudget budget) async {
    final chosen = await chooseBudget(context, ref, budget);
    if (chosen && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Budget set to "${budget.name}".')));
    }
  }

  Future<void> _forgetPdfPasswords() async {
    await ref.read(secretStoreProvider).forgetAllPdfPasswords();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved statement passwords forgotten.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final check = ref.watch(connectionControllerProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final parseOnDevice = ref.watch(parseOnDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        // Debug builds only: long-press the title for the dev page.
        title: GestureDetector(
          onLongPress: kDebugMode ? () => context.push('/dev') : null,
          child: const Text('Settings'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          const _SectionTitle('Connection'),
          Text('Backend', style: context.text.titleMedium),
          const SizedBox(height: Space.xs),
          Text('The bridge between this app and your Actual server.', style: muted),
          const SizedBox(height: Space.md),
          ConnectionFields(
            urlController: _urlController,
            tokenController: _tokenController,
            onSubmitted: _save,
          ),
          const SizedBox(height: Space.xl),
          BusyButton(
            label: 'Save and test',
            busy: check.status == ConnectionStatus.testing,
            onPressed: _save,
          ),
          AnimatedSize(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: check.message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: InlineNote(
                      message: check.message!,
                      tone: check.isConnected ? NoteTone.success : NoteTone.error,
                    ),
                  ),
          ),
          const SizedBox(height: Space.xl),
          Text('Actual server', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          const ActualServerCard(),
          const SizedBox(height: Space.xxl + Space.sm),
          const _SectionTitle('Budget'),
          if (!check.actualConfigured)
            Text(
              check.isConnected
                  ? 'Connect an Actual server above to choose a budget.'
                  : 'Connect the backend and an Actual server to choose a budget.',
              style: muted,
            )
          else if (check.budgetsError != null)
            InlineNote(message: check.budgetsError!, tone: NoteTone.error)
          else if (!check.loadingBudgets && check.budgets.isEmpty)
            InlineNote(
              // Connected with an empty list means the server really has none;
              // otherwise the list just hasn't been loaded yet.
              message: check.isConnected
                  ? noBudgetsMessage
                  : config.budgetName == null
                  ? 'Save and test the connection to load your budgets.'
                  : 'Using "${config.budgetName}". Save and test the connection to switch budgets.',
            )
          else
            BudgetList(
              budgets: check.budgets,
              loading: check.loadingBudgets,
              selectedSyncId: config.budgetSyncId,
              onSelect: _selectBudget,
            ),
          const SizedBox(height: Space.xxl + Space.sm),
          const _SectionTitle('Categories'),
          Text(
            'The payee to category mappings that pre-fill categories when you import or add, '
            "and the app's own categories, used until Actual is connected.",
            style: muted,
          ),
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/settings/categories'),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Open category memory'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/settings/category-list'),
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('Edit categories'),
              ),
              if (ref.watch(linkStateProvider).valueOrNull == LinkState.ready)
                OutlinedButton.icon(
                  onPressed: () => context.push('/match-categories'),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Match with Actual'),
                ),
            ],
          ),
          const SizedBox(height: Space.xxl + Space.sm),
          const _SectionTitle('Privacy'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Read statements on this phone'),
            subtitle: Text(
              parseOnDevice
                  ? "Statements stay on the phone. One the app can't read is sent to the "
                        'backend only if you ask.'
                  : 'Statements are sent to the importer address above. They reach a cloud '
                        'service only when its parser mode is "ai" or "both".',
              style: muted,
            ),
            value: parseOnDevice,
            onChanged: (value) => setParseOnDevice(ref, value),
          ),
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _forgetPdfPasswords,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Forget statement passwords'),
            ),
          ),
          const SizedBox(height: Space.xxl + Space.sm),
          const _SectionTitle('Diagnostics'),
          Text('Logs of what the app did, to find out what went wrong.', style: muted),
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/settings/diagnostics'),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Logs and diagnostics'),
            ),
          ),
          const SizedBox(height: Space.xxl + Space.sm),
          const _SectionTitle('Setup guide'),
          Text('Walk through connecting and choosing a budget again.', style: muted),
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/setup'),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Run setup again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Text(text, style: context.text.titleLarge),
    );
  }
}
