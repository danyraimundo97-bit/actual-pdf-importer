import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/settings_group.dart';
import '../../categories/screens/match_categories_screen.dart';
import '../connection_controller.dart';
import '../widgets/budget_sheet.dart';

/// Settings as a grouped overview (docs/plans/settings-polish.md): the
/// backend, Actual and the budget with their status first, then the groups.
/// The backend and Actual each have their own screen; the budget is a sheet.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Check the saved connection right away, so the overview shows the real
    // state of the backend and Actual.
    final url = ref.read(appConfigProvider).backendUrl;
    if (url != null && url.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(connectionControllerProvider.notifier).test();
      });
    }
  }

  Future<void> _forgetPdfPasswords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget statement passwords?'),
        content: const Text(
          "The passwords saved for opening statements are removed from this phone. You'll be asked "
          'again the next time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(secretStoreProvider).forgetAllPdfPasswords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statement passwords forgotten.')));
    }
  }

  Future<void> _chooseBudget() async {
    final name = await showBudgetSheet(context);
    if (name != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to "$name".')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final check = ref.watch(connectionControllerProvider);
    final parseOnDevice = ref.watch(parseOnDeviceProvider);
    final ready = ref.watch(linkStateProvider).valueOrNull == LinkState.ready;
    final pending = ready ? ref.watch(pendingCategoryMatchesProvider).valueOrNull ?? 0 : 0;
    final hasBackend = config.backendUrl?.isNotEmpty == true;
    final backend = backendStatus(config, check);
    final actual = actualStatus(config, check);

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
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.dns_outlined,
                title: 'Backend',
                subtitle: StatusDot(status: backend.status, label: backend.label, value: backend.value),
                onTap: () => context.push('/settings/backend'),
              ),
              SettingsRow(
                icon: Icons.link_rounded,
                title: 'Actual',
                subtitle: StatusDot(status: actual.status, label: actual.label, value: actual.value),
                onTap: () => context.push('/settings/actual'),
              ),
              SettingsRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budget',
                subtitle: Text(
                  check.actualConfigured
                      ? config.budgetName ?? 'Choose a budget'
                      : config.budgetName ?? 'Connect Actual first',
                ),
                trailing: Icon(Icons.unfold_more_rounded, size: 20, color: context.colors.outline),
                enabled: check.actualConfigured,
                onTap: _chooseBudget,
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          SettingsGroup(
            label: 'Categories',
            children: [
              SettingsRow(
                icon: Icons.history_rounded,
                title: 'Category memory',
                onTap: () => context.push('/settings/categories'),
              ),
              SettingsRow(
                icon: Icons.sell_outlined,
                title: 'Categories',
                onTap: () => context.push('/settings/category-list'),
              ),
              if (ready)
                SettingsRow(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Match with Actual',
                  trailing: pending > 0 ? _CountChip('$pending to do') : null,
                  onTap: () => context.push('/match-categories'),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          // One row that already says what it is: no group label above it.
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.inventory_2_outlined,
                title: 'Backups',
                subtitle: Text(hasBackend ? 'Scheduled by the backend' : 'Export and import on this phone'),
                onTap: () => context.push('/settings/backups'),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          SettingsGroup(
            label: 'Privacy',
            children: [
              SettingsSwitchRow(
                icon: Icons.smartphone_rounded,
                title: 'Read statements on this phone',
                subtitle: parseOnDevice
                    ? "Statements stay on the phone. One the app can't read is sent to the backend only "
                          'if you ask.'
                    : 'Statements are sent to the backend, which reads them with its AI provider.',
                value: parseOnDevice,
                onChanged: (value) => setParseOnDevice(ref, value),
              ),
              SettingsRow(
                icon: Icons.key_off_outlined,
                title: 'Forget statement passwords',
                destructive: true,
                onTap: _forgetPdfPasswords,
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          SettingsGroup(
            label: 'Help',
            children: [
              SettingsRow(
                icon: Icons.receipt_long_outlined,
                title: 'Logs and diagnostics',
                onTap: () => context.push('/settings/diagnostics'),
              ),
              SettingsRow(
                icon: Icons.restart_alt_rounded,
                title: 'Run setup again',
                onTap: () => context.push('/setup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef StatusView = ({SettingsStatus status, String label, String? value});

/// The backend's row: not set up, being checked, connected (with its host),
/// or failing.
StatusView backendStatus(AppConfig config, ConnectionCheck check) {
  final url = config.backendUrl;
  if (url == null || url.isEmpty) return (status: SettingsStatus.off, label: 'Not set up', value: null);
  final host = Uri.tryParse(url)?.host;
  return switch (check.status) {
    ConnectionStatus.connected => (status: SettingsStatus.ok, label: 'Connected', value: host),
    ConnectionStatus.failed => (status: SettingsStatus.failing, label: "Can't reach it", value: host),
    _ => (status: SettingsStatus.busy, label: 'Checking…', value: null),
  };
}

/// Actual's row, which depends on the backend.
StatusView actualStatus(AppConfig config, ConnectionCheck check) {
  if (config.backendUrl == null || config.backendUrl!.isEmpty || check.status == ConnectionStatus.failed) {
    return (status: SettingsStatus.off, label: 'Needs the backend', value: null);
  }
  if (!check.isConnected) return (status: SettingsStatus.busy, label: 'Checking…', value: null);
  if (!check.actualConfigured) return (status: SettingsStatus.off, label: 'Not set up', value: null);
  final version = check.actual?.serverVersion;
  final host = Uri.tryParse(check.actual?.serverUrl ?? '')?.host;
  return (
    status: SettingsStatus.ok,
    label: 'Connected',
    value: version != null ? 'v$version' : (host == null || host.isEmpty ? null : host),
  );
}

class _CountChip extends StatelessWidget {
  final String text;

  const _CountChip(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(999)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
            child: Text(text, style: context.text.labelMedium?.copyWith(color: colors.onPrimaryContainer)),
          ),
        ),
        const SizedBox(width: Space.sm),
        Icon(Icons.chevron_right_rounded, size: 20, color: colors.outline),
      ],
    );
  }
}
