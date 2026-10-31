import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/import/inbox_controller.dart';
import 'services/share_intent_service.dart';

/// Bottom navigation around the four main tabs. Also owns share-sheet
/// intake: a PDF shared into the app lands in the import inbox whichever
/// tab is open, and the Import tab is brought forward.
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  static const importTabIndex = 1;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _shareService = ShareIntentService();

  @override
  void initState() {
    super.initState();
    _shareService.takeInitial().then((pdf) {
      if (pdf != null) _receive(pdf);
    });
    _shareService.listen(_receive);
  }

  @override
  void dispose() {
    _shareService.dispose();
    super.dispose();
  }

  Future<void> _receive(SharedPdf shared) async {
    try {
      final bytes = await File(shared.path).readAsBytes();
      ref.read(inboxProvider.notifier).add(filename: shared.filename, bytes: bytes);
      if (mounted) widget.shell.goBranch(AppShell.importTabIndex);
    } on FileSystemException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not read the shared file.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inboxWaiting = ref.watch(
      inboxProvider.select(
        (items) => items
            .where((i) => i.status == InboxStatus.ready || i.status == InboxStatus.needsPassword)
            .length,
      ),
    );

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        // Re-tapping the current tab returns it to its first page.
        onDestinationSelected: (i) =>
            widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: inboxWaiting > 0,
              label: Text('$inboxWaiting'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: inboxWaiting > 0,
              label: Text('$inboxWaiting'),
              child: const Icon(Icons.inbox_rounded),
            ),
            label: 'Import',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell_rounded),
            label: 'Memory',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
