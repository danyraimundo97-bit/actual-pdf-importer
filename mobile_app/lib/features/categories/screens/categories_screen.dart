import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/db/local_category_store.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_emoji.dart';
import '../../../shared/widgets/skeleton.dart';

const _log = AppLog('categories');

/// Settings → Categories: the app's own categories (the predefined set and
/// the user's), used while Actual isn't connected. Rename, hide, add.
/// Nothing is deleted: a hidden category keeps its mappings and can be shown
/// again.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

enum _MenuAction { addGroup, restorePresets }

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<ManagedGroup>? _groups;

  LocalCategoryStore get _store => ref.read(localCategoryStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _store.allGroups();
    if (mounted) setState(() => _groups = groups);
  }

  /// Runs a change, reloads, and lets screens that show categories refresh.
  Future<void> _change(Future<void> Function() change) async {
    await change();
    ref.read(categoryMemoryRevisionProvider.notifier).state++;
    await _load();
  }

  Future<String?> _askName({required String title, String initial = '', required String action}) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(title: title, initial: initial, action: action),
    );
  }

  Future<void> _renameCategory(ManagedCategory category) async {
    final name = await _askName(title: 'Rename category', initial: category.name, action: 'Rename');
    if (name == null || name == category.name) return;
    await _change(() => _store.renameCategory(category.id, name));
    _log.info('Category renamed', {'category': category.id});
  }

  Future<void> _chooseEmoji(ManagedCategory category) async {
    final emoji = await pickEmoji(context, categoryName: category.name, current: category.emoji);
    if (emoji == null || emoji == (category.emoji ?? '')) return;
    await _change(() => _store.setCategoryEmoji(category.id, emoji));
    _log.info('Category emoji changed', {'category': category.id});
  }

  Future<void> _renameGroup(ManagedGroup group) async {
    final name = await _askName(title: 'Rename group', initial: group.name, action: 'Rename');
    if (name == null || name == group.name) return;
    await _change(() => _store.renameGroup(group.id, name));
    _log.info('Category group renamed', {'group': group.id});
  }

  Future<void> _addCategory(ManagedGroup group) async {
    final name = await _askName(title: 'New category in ${group.name}', action: 'Add');
    if (name == null) return;
    late final String id;
    await _change(() async => id = await _store.addCategory(group.id, name));
    _log.info('Category added', {'category': id, 'group': group.id});
  }

  Future<void> _addGroup() async {
    final name = await _askName(title: 'New group', action: 'Add');
    if (name == null) return;
    late final String id;
    await _change(() async => id = await _store.addGroup(name));
    _log.info('Category group added', {'group': id});
  }

  Future<void> _toggleHidden(ManagedCategory category) async {
    await _change(() => _store.setCategoryHidden(category.id, !category.hidden));
    _log.info(category.hidden ? 'Category shown' : 'Category hidden', {'category': category.id});
  }

  Future<void> _restorePresets() async {
    late final int restored;
    await _change(() async => restored = await _store.restoreHiddenPresets());
    _log.info('Hidden presets restored', {'categories': restored});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored == 0
              ? 'No predefined category was hidden.'
              : 'Brought back $restored predefined ${restored == 1 ? 'category' : 'categories'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          PopupMenuButton<_MenuAction>(
            onSelected: (action) => switch (action) {
              _MenuAction.addGroup => _addGroup(),
              _MenuAction.restorePresets => _restorePresets(),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: _MenuAction.addGroup, child: Text('Add group')),
              PopupMenuItem(value: _MenuAction.restorePresets, child: Text('Show hidden predefined categories')),
            ],
          ),
        ],
      ),
      body: groups == null
          ? const SkeletonRows(count: 8)
          : ListView(
              padding: const EdgeInsets.only(bottom: Space.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                  child: Text(
                    "The app's own categories, used until Actual is connected. Hiding one takes it out "
                    'of the picker and suggestions; its remembered payees come back if you show it again.',
                    style: muted,
                  ),
                ),
                for (final group in groups) ...[
                  _GroupHeader(group: group, onRename: () => _renameGroup(group), onAdd: () => _addCategory(group)),
                  for (final category in group.categories)
                    _CategoryTile(
                      category: category,
                      onRename: () => _renameCategory(category),
                      onChooseEmoji: () => _chooseEmoji(category),
                      onToggleHidden: () => _toggleHidden(category),
                    ),
                  if (group.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
                      child: Text('No categories yet.', style: muted),
                    ),
                ],
              ],
            ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final ManagedGroup group;
  final VoidCallback onRename;
  final VoidCallback onAdd;

  const _GroupHeader({required this.group, required this.onRename, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.sm, Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(group.isIncome ? '${group.name} · income' : group.name, style: context.text.titleSmall)),
          IconButton(
            tooltip: 'Rename ${group.name}',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onRename,
          ),
          IconButton(
            tooltip: 'Add a category to ${group.name}',
            icon: const Icon(Icons.add_rounded, size: 22),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ManagedCategory category;
  final VoidCallback onRename;
  final VoidCallback onChooseEmoji;
  final VoidCallback onToggleHidden;

  const _CategoryTile({
    required this.category,
    required this.onRename,
    required this.onChooseEmoji,
    required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      // The emoji's own touch target reaches into the gutter, so it stays in
      // line with the group's name above while being easy to hit.
      contentPadding: const EdgeInsets.only(left: Space.gutter - 12, right: Space.sm),
      minLeadingWidth: 44,
      horizontalTitleGap: Space.xs,
      leading: IconButton(
        tooltip: 'Choose an emoji for ${category.name}',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: CategoryGlyph(emoji: category.emoji, name: category.name, muted: category.hidden),
        onPressed: onChooseEmoji,
      ),
      title: Text(category.name, style: category.hidden ? TextStyle(color: colors.onSurfaceVariant) : null),
      subtitle: category.hidden ? const Text('Hidden') : (category.isPreset ? null : const Text('Yours')),
      onTap: onRename,
      trailing: IconButton(
        tooltip: category.hidden ? 'Show ${category.name}' : 'Hide ${category.name}',
        icon: Icon(category.hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: onToggleHidden,
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String action;

  const _NameDialog({required this.title, required this.initial, required this.action});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) =>
              FilledButton(onPressed: _controller.text.trim().isEmpty ? null : _submit, child: Text(widget.action)),
        ),
      ],
    );
  }
}
