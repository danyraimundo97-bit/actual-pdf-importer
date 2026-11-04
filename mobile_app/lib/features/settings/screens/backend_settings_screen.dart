import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/inline_note.dart';
import '../connection_controller.dart';
import '../widgets/connection_widgets.dart';

/// Settings › Backend: the address and token, with "Save and test" pinned to
/// the bottom. The check result shows inline under the fields.
class BackendSettingsScreen extends ConsumerStatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  ConsumerState<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends ConsumerState<BackendSettingsScreen> {
  late final TextEditingController _url;
  final _token = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(appConfigProvider).backendUrl ?? '');
    ref.read(secretStoreProvider).apiToken.then((token) {
      if (mounted && token != null) setState(() => _token.text = token);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await ref.read(connectionControllerProvider.notifier).saveAndTest(url: _url.text, token: _token.text);
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(connectionControllerProvider);
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: const Text('Backend')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [
          Text(
            'The backend runs on your server: it talks to Actual, keeps backups and can read statements '
            'with AI. The app works without it.',
            style: muted,
          ),
          const SizedBox(height: Space.xl),
          ConnectionFields(urlController: _url, tokenController: _token, onSubmitted: _save),
          AnimatedSize(
            duration: Motion.of(context, Motion.small),
            curve: Motion.easeOut,
            alignment: Alignment.topCenter,
            child: check.message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.lg),
                    child: InlineNote(
                      message: check.message!,
                      tone: check.isConnected ? NoteTone.success : NoteTone.error,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
            child: BusyButton(label: 'Save and test', busy: check.status == ConnectionStatus.testing, onPressed: _save),
          ),
        ),
      ),
    );
  }
}
