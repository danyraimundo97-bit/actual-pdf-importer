import 'package:flutter/material.dart';

import '../../data/models/actual_category.dart';

class CategoryChoice {
  final String id;
  final String name;

  const CategoryChoice(this.id, this.name);
}

/// Searchable, grouped category picker — shared by the review screen's
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search categories',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              if (widget.groups.isEmpty)
                const Expanded(
                  child: Center(child: Text('No categories loaded from Actual yet.')),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      for (final group in sections) _GroupSection(group: group, query: query),
                    ],
                  ),
                ),
            ],
          ),
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
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(group.name, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final category in categories)
          ListTile(
            dense: true,
            title: Text(category.name),
            onTap: () => Navigator.pop(context, CategoryChoice(category.id, category.name)),
          ),
      ],
    );
  }
}
