import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/fold.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_account.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/bank_notification_sheet.dart';

/// Setting up the listener, and what's waiting to be added.
class BankNotificationsScreen extends ConsumerStatefulWidget {
  const BankNotificationsScreen({super.key});

  @override
  ConsumerState<BankNotificationsScreen> createState() => _BankNotificationsScreenState();
}

class _BankNotificationsScreenState extends ConsumerState<BankNotificationsScreen> with WidgetsBindingObserver {
  bool? _enabled;
  Set<String> _tracked = const {};
  List<({String package, String label})> _installed = const [];
  List<ActualAccount> _accounts = const [];

  String _trackedLabel() => [
    for (final app in _installed)
      if (_tracked.contains(app.package)) app.label,
  ].join(', ');

  /// The account set for an app, if it still exists in the budget on screen.
  String _accountName(String package) {
    final id = ref.read(settingsStoreProvider).defaultAccountForApp(package);
    return _accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Automatic';
  }

  Future<void> _chooseAccount(String package, String label) async {
    final settings = ref.read(settingsStoreProvider);
    final current = settings.defaultAccountForApp(package);
    // A record, so that choosing "Automatic" differs from backing out.
    final chosen = await showModalBottomSheet<({String? id})>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
              child: Text('$label starts on', style: context.text.titleLarge),
            ),
            ListTile(
              title: const Text('Automatic'),
              subtitle: const Text("The bank's account, else the last one used"),
              trailing: current == null ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, (id: null)),
            ),
            for (final a in _accounts)
              ListTile(
                title: Text(a.name),
                trailing: a.id == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, (id: a.id)),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await settings.setDefaultAccountForApp(package, chosen.id);
    if (mounted) setState(() {});
  }

  Future<void> _chooseApps() async {
    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChooseAppsSheet(apps: _installed, selected: _tracked),
    );
    if (chosen == null) return;
    await ref.read(bankNotificationsProvider).setTrackedApps(chosen);
    if (mounted) setState(() => _tracked = chosen);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from Android's settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
      ref.invalidate(bankNotificationsWaitingProvider);
    }
  }

  Future<void> _check() async {
    final channel = ref.read(bankNotificationsProvider);
    final enabled = await channel.isEnabled();
    final tracked = await channel.trackedApps();
    final installed = await channel.installedApps();
    final scope = await ref.read(ledgerScopeProvider.future);
    final options = await ref.read(ledgerReportsProvider).quickAddOptions(scope);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _tracked = tracked;
      _installed = installed;
      _accounts = options.accounts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.read(bankNotificationsProvider);
    final waiting = ref.watch(bankNotificationsWaitingProvider).valueOrNull ?? const [];
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Bank notifications')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'When an app you choose sends a notification, this app sends one too. Tap it to add the transaction. '
              'Other apps\' notifications are ignored, and this stays on your phone.',
              style: muted,
            ),
          ),
          if (!channel.available)
            Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: Text('Only on Android.', style: muted),
            )
          else ...[
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: _enabled == true
                  ? Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: context.tokens.inflow),
                        const SizedBox(width: Space.sm),
                        const Expanded(child: Text('Listening')),
                        TextButton(onPressed: channel.openSettings, child: const Text('Change')),
                      ],
                    )
                  : FilledButton(
                      onPressed: () async {
                        await channel.requestPostPermission();
                        await channel.openSettings();
                      },
                      child: const Text('Allow notification access'),
                    ),
            ),
          ],
          if (channel.available) ...[
            const SizedBox(height: Space.lg),
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('Apps to track'),
              subtitle: Text(_tracked.isEmpty ? 'None yet: choose your banks and MB WAY' : _trackedLabel()),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _chooseApps,
            ),
            for (final app in _installed)
              if (_tracked.contains(app.package))
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.xxl, right: Space.gutter),
                  title: Text(app.label),
                  subtitle: Text('Starts on: ${_accountName(app.package)}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseAccount(app.package, app.label),
                ),
          ],
          const SizedBox(height: Space.lg),
          if (waiting.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing waiting',
              message: 'Bank notifications you haven\'t added yet show up here.',
            )
          else
            for (final n in waiting)
              ListTile(
                title: Text(n.title.isEmpty ? n.bankName : n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${n.bankName} · ${dayLabel(n.postedAt)} · ${n.text}', maxLines: 2),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await showBankNotificationSheet(context, n);
                  ref.invalidate(bankNotificationsWaitingProvider);
                },
              ),
        ],
      ),
    );
  }
}

/// Picks which apps' notifications to read. Pops with the chosen packages.
class ChooseAppsSheet extends StatefulWidget {
  final List<({String package, String label})> apps;
  final Set<String> selected;

  const ChooseAppsSheet({super.key, required this.apps, required this.selected});

  @override
  State<ChooseAppsSheet> createState() => _ChooseAppsSheetState();
}

class _ChooseAppsSheetState extends State<ChooseAppsSheet> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = foldAccents(_query).trim().toLowerCase();
    final shown = [
      for (final app in widget.apps)
        if (foldAccents(app.label).toLowerCase().contains(query)) app,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
              child: Text('Apps to track', style: context.text.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: TextField(
                decoration: const InputDecoration(hintText: 'Search apps', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (text) => setState(() => _query = text),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  for (final app in shown)
                    CheckboxListTile(
                      title: Text(app.label),
                      value: _selected.contains(app.package),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _selected.add(app.package);
                        } else {
                          _selected.remove(app.package);
                        }
                      }),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
