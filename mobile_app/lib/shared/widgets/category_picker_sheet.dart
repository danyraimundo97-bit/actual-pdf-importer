import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../data/models/actual_category.dart';

class CategoryChoice {
  final String id;
  final String name;

  const CategoryChoice(this.id, this.name);
}

/// Searchable, grouped category picker, shared by the review screen's
/// per-transaction category chip and the Category Memory "add mapping"
/// sheet, so both pick from Actual's real categories rather than a
/// free-text id field.
Future<CategoryChoice?> pickCategory(BuildContext context, List<ActualCategoryGroup> groups) {
  return showModalBottomSheet<CategoryChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => CategoryPickerSheet(groups: groups),
  );
}

class CategoryPickerSheet extends StatefulWidget {
  final List<ActualCategoryGroup> groups;

  const CategoryPickerSheet({super.key, required this.groups});

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final sections = widget.groups.where((g) => _groupMatches(g, query)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose a category', style: context.text.titleLarge),
                  const SizedBox(height: Space.md),
                  TextField(
                    autofocus: widget.groups.isNotEmpty,
                    decoration: const InputDecoration(
                      hintText: 'Search categories',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.groups.isEmpty
                  ? const _PickerMessage(
                      'No categories loaded from Actual yet. Check the connection in Settings.',
                    )
                  : sections.isEmpty
                  ? _PickerMessage('No category matches "${_query.trim()}".')
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: Space.xl),
                      children: [
                        for (final group in sections) _GroupSection(group: group, query: query),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _groupMatches(ActualCategoryGroup group, String query) {
    if (query.isEmpty) return true;
    if (group.name.toLowerCase().contains(query)) return true;
    return group.categories.any((c) => c.name.toLowerCase().contains(query));
  }
}

class _GroupSection extends StatelessWidget {
  final ActualCategoryGroup group;
  final String query;

  const _GroupSection({required this.group, required this.query});

  @override
  Widget build(BuildContext context) {
    final groupNameMatches = group.name.toLowerCase().contains(query);
    final categories = query.isEmpty || groupNameMatches
        ? group.categories
        : group.categories.where((c) => c.name.toLowerCase().contains(query)).toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
          child: Text(
            group.name,
            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        for (final category in categories)
          ListTile(
            visualDensity: VisualDensity.compact,
            title: Text(category.name),
            onTap: () => Navigator.pop(context, CategoryChoice(category.id, category.name)),
          ),
      ],
    );
  }
}

class _PickerMessage extends StatelessWidget {
  final String message;

  const _PickerMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
      child: Text(
        message,
        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}
