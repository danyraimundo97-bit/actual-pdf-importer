import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../data/providers.dart';
import 'empty_state.dart';

/// Whether [error] means "Actual isn't connected" rather than a failure:
/// screens show [ConnectActualState] for it instead of an error.
bool isActualNotConnected(Object? error) =>
    error is ApiException && (error.code == 'ACTUAL_NOT_CONFIGURED' || error.code == 'NO_BUDGET_SELECTED');

/// The one "connect first" state for every screen that needs Actual, worded
/// for how far the app is connected. Its button opens Settings → Connection.
class ConnectActualState extends StatelessWidget {
  final LinkState state;

  const ConnectActualState({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (state) {
      LinkState.noBackend => (
          'Connect your Actual server',
          'Balances, your budget and quick add come from Actual, through the backend that '
              'connects this app to it. Set it up in Settings whenever you are ready.',
        ),
      LinkState.noActual => (
          'Connect your Actual server',
          'The backend is running, but it is not linked to an Actual server yet. '
              'Add your server in Settings to see your money here.',
        ),
      LinkState.noBudget => (
          'Choose a budget',
          'Actual is connected. Pick which budget to use in Settings.',
        ),
      LinkState.ready => ('', ''),
    };
    return EmptyState(
      icon: Icons.link_rounded,
      title: title,
      message: message,
      actionLabel: state == LinkState.noBudget ? 'Choose a budget' : 'Connect',
      actionIcon: Icons.arrow_forward_rounded,
      onAction: () => context.go('/settings'),
    );
  }
}

/// Shows [child] once Actual is connected and a budget chosen; otherwise
/// the connect state. While the link state is loading, or if the backend
/// can't be reached, [child] is shown: it has its own skeleton and error.
class RequiresActual extends ConsumerWidget {
  final Widget child;

  const RequiresActual({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(linkStateProvider);
    final state = link.valueOrNull;
    if (state == null || state == LinkState.ready) return child;
    return ConnectActualState(state: state);
  }
}
