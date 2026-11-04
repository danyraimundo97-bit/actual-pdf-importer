import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/settings_group.dart';
import '../connection_controller.dart';
import '../widgets/actual_server_card.dart';

/// Settings › Actual: the backend's Actual server ([ActualServerCard]).
/// Actual is reached through the backend, so without one this explains that
/// and links to the Backend screen.
class ActualSettingsScreen extends ConsumerWidget {
  const ActualSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(connectionControllerProvider);
    final hasBackend = ref.watch(appConfigProvider.select((c) => c.backendUrl?.isNotEmpty == true));
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);

    final Widget body;
    if (check.isConnected) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The backend signs in to your Actual server. Importing into Actual, matching categories and '
            'budget backups need it.',
            style: muted,
          ),
          const SizedBox(height: Space.xl),
          const ActualServerCard(),
        ],
      );
    } else if (hasBackend && check.status != ConnectionStatus.failed) {
      body = const Padding(
        padding: EdgeInsets.only(top: Space.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: settingsGroupColor(context),
          borderRadius: Radii.controlAll,
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasBackend ? "Can't reach the backend" : 'Connect the backend first',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: Space.xs),
              Text(
                hasBackend
                    ? 'Actual is reached through the backend. Check its address and that it is running.'
                    : 'Actual is reached through the backend, so set that up and come back here.',
                style: muted,
              ),
              const SizedBox(height: Space.lg),
              OutlinedButton(
                onPressed: () => context.pushReplacement('/settings/backend'),
                child: Text(hasBackend ? 'Check the backend' : 'Set up the backend'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Actual')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [body],
      ),
    );
  }
}
