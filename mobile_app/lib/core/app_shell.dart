import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/categories/category_sync_controller.dart';
import '../features/import/inbox_controller.dart';
import 'services/share_intent_service.dart';

/// Bottom navigation around the four main tabs (Home, Budget, Import,
/// Settings), and the quick-add button on Home and Budget. Also owns
/// share-sheet intake: a PDF shared into the app lands in the import inbox
/// whichever tab is open, and the Import tab is brought forward.
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  static const homeTabIndex = 0;
  static const budgetTabIndex = 1;
  static const importTabIndex = 2;

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
    if (ref.read(databaseWasResetProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _explainDatabaseReset());
    }
  }

  /// The database couldn't be opened with its key (docs/plans/local-ledger.md,
  /// Phase 1) and the app started with an empty one. Said once.
  Future<void> _explainDatabaseReset() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("This phone's data was reset"),
        content: const Text(
          "The app couldn't open its data on this phone, so it started again with none. With a backend, "
          'your categories and category memory come back on the next sync. A backup file can be '
          'restored in Settings › Backups.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    await ref.read(settingsStoreProvider).setDatabaseWasReset(false);
    ref.read(databaseWasResetProvider.notifier).state = false;
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
    // Category sync (when there's a backend): once the connection state is
    // known or changes (app start, backend or Actual connected, budget
    // switched), and shortly after the phone's categories or memory change.
    ref.listen(linkStateProvider, (previous, next) {
      if (next.hasValue && next.valueOrNull != previous?.valueOrNull) {
        ref.read(categorySyncProvider.notifier).syncNow();
      }
    });
    ref.listen(categoryMemoryRevisionProvider, (_, _) => ref.read(categorySyncProvider.notifier).request());
    ref.listen(databaseWasResetProvider, (previous, next) {
      if (next && previous != true) _explainDatabaseReset();
    });

    final inboxWaiting = ref.watch(
      inboxProvider.select(
        (items) => items
            .where(
              (i) =>
                  i.status == InboxStatus.ready ||
                  i.status == InboxStatus.needsPassword ||
                  i.status == InboxStatus.unrecognized,
            )
            .length,
      ),
    );

    final index = widget.shell.currentIndex;
    final showAdd = index == AppShell.homeTabIndex || index == AppShell.budgetTabIndex;

    return Scaffold(
      body: widget.shell,
      floatingActionButton: showAdd
          ? FloatingActionButton.extended(
              heroTag: 'quick-add',
              onPressed: () => context.push('/add'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        // Re-tapping the current tab returns it to its first page.
        onDestinationSelected: (i) =>
            widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.donut_small_outlined),
            selectedIcon: Icon(Icons.donut_small_rounded),
            label: 'Budget',
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
