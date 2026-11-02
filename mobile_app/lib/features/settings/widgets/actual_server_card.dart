import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../connection_controller.dart';

/// The backend's link to an Actual server: shown once the backend answers,
/// in Settings and on the setup guide's last page. Connected → the server
/// and Change / Disconnect; not connected (or changing) → address and
/// password with "Test & connect", errors inline by the backend's code;
/// locked (set in the backend's .env) → read-only.
///
/// The password goes straight to the backend, which keeps it; the app
/// doesn't store it.
class ActualServerCard extends ConsumerStatefulWidget {
  /// Called after a successful connect (the setup page reveals the budgets).
  final VoidCallback? onConnected;

  const ActualServerCard({super.key, this.onConnected});

  @override
  ConsumerState<ActualServerCard> createState() => _ActualServerCardState();
}

class _ActualServerCardState extends ConsumerState<ActualServerCard> {
  final _url = TextEditingController();
  final _password = TextEditingController();
  bool _editing = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _url.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(connectionControllerProvider.notifier)
        .connectActual(serverUrl: _url.text, password: _password.text);
    if (!mounted) return;
    if (ok) {
      _password.clear();
      setState(() => _editing = false);
      widget.onConnected?.call();
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Actual?'),
        content: const Text(
          'The backend forgets this server. Nothing in Actual is changed, and statements can '
          'still be read here. You can connect again any time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(connectionControllerProvider.notifier).disconnectActual();
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(connectionControllerProvider);
    final actual = check.actual;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (!check.isConnected) {
      return Text('Connect the backend first: the app reaches Actual through it.', style: muted);
    }

    final configured = check.actualConfigured;
    final locked = actual?.locked ?? check.config?.actualLocked ?? false;
    final showForm = !locked && (!configured || _editing);

    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (configured && !_editing)
            _ConnectedRow(
              serverUrl: actual?.serverUrl,
              version: actual?.serverVersion,
              locked: locked,
              onChange: locked ? null : () => setState(() => _editing = true),
              onDisconnect: locked ? null : _disconnect,
            ),
          if (showForm) ...[
            LabeledField(
              label: 'Actual server address',
              helper: 'As the backend reaches it, e.g. your server\'s network address.',
              child: TextField(
                controller: _url,
                decoration: const InputDecoration(hintText: 'http://192.168.1.50:5006'),
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: Space.lg),
            LabeledField(
              label: 'Server password',
              helper: 'The password you log in to Actual with.',
              child: TextField(
                controller: _password,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _connect(),
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: BusyButton(
                    label: 'Test & connect',
                    busy: check.actualStatus == ConnectionStatus.testing,
                    onPressed: _connect,
                  ),
                ),
                if (_editing) ...[
                  const SizedBox(width: Space.sm),
                  TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                ],
              ],
            ),
          ],
          if (check.actualMessage != null) ...[
            const SizedBox(height: Space.md),
            InlineNote(
              message: check.actualMessage!,
              tone: check.actualStatus == ConnectionStatus.failed ? NoteTone.error : NoteTone.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  final String? serverUrl;
  final String? version;
  final bool locked;
  final VoidCallback? onChange;
  final VoidCallback? onDisconnect;

  const _ConnectedRow({
    required this.serverUrl,
    required this.version,
    required this.locked,
    required this.onChange,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: colors.surfaceContainer, borderRadius: Radii.controlAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 20, color: colors.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  serverUrl == null ? 'Connected to Actual' : 'Connected to $serverUrl',
                  style: context.text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (version != null || locked) ...[
            const SizedBox(height: Space.xs),
            Text(
              [
                if (version != null) 'Actual $version',
                if (locked) "Set in the backend's .env, so it can only be changed there",
              ].join(' · '),
              style: muted,
            ),
          ],
          if (onChange != null || onDisconnect != null) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                if (onChange != null) TextButton(onPressed: onChange, child: const Text('Change')),
                if (onDisconnect != null)
                  TextButton(
                    onPressed: onDisconnect,
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
