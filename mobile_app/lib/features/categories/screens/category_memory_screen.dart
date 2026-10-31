import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_account.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/category_mapping.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/sheet_body.dart';
import '../../../shared/widgets/skeleton.dart';

class CategoryMemoryScreen extends ConsumerStatefulWidget {
  const CategoryMemoryScreen({super.key});

  @override
  ConsumerState<CategoryMemoryScreen> createState() => _CategoryMemoryScreenState();
}

class _CategoryMemoryScreenState extends ConsumerState<CategoryMemoryScreen> {
  List<CategoryMapping> _mappings = [];
  List<ActualCategoryGroup> _categoryGroups = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      final results = await Future.wait([
        ref.read(categoriesApiProvider).list(budgetSyncId: budgetSyncId),
        ref.read(importerApiProvider).getActualCategories(budgetSyncId: budgetSyncId),
      ]);
      if (!mounted) return;
      setState(() {
        _mappings = results[0] as List<CategoryMapping>;
        _categoryGroups = results[1] as List<ActualCategoryGroup>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(CategoryMapping mapping) async {
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      await ref.read(categoriesApiProvider).delete(mapping.payee, budgetSyncId: budgetSyncId);
      if (!mounted) return;
      setState(() => _mappings.removeWhere((m) => m.payee == mapping.payee));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forgot "${mapping.payee}".'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _restore(mapping)),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _restore(CategoryMapping mapping) async {
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      await ref
          .read(categoriesApiProvider)
          .upsert(
            payee: mapping.payee,
            categoryId: mapping.categoryId,
            categoryName: mapping.categoryName,
            budgetSyncId: budgetSyncId,
          );
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addOrEdit({CategoryMapping? existing}) async {
    final result = await showModalBottomSheet<_MappingEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MappingEditSheet(existing: existing, categoryGroups: _categoryGroups),
    );
    if (result == null) return;
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      await ref
          .read(categoriesApiProvider)
          .upsert(
            payee: result.payee,
            categoryId: result.categoryId,
            categoryName: result.categoryName,
            budgetSyncId: budgetSyncId,
          );
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _learnFromActual() async {
    final result = await showModalBottomSheet<_LearnRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _LearnFromActualSheet(),
    );
    if (result == null) return;
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      final outcome = await ref
          .read(categoriesApiProvider)
          .learnFromActual(
            accountId: result.accountId,
            startDate: result.startDate,
            endDate: result.endDate,
            budgetSyncId: budgetSyncId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Learned ${outcome.learned} mappings from ${outcome.scanned} transactions.',
            ),
          ),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _mappings
        : _mappings
              .where(
                (m) =>
                    m.payee.toLowerCase().contains(query) ||
                    (m.categoryName ?? '').toLowerCase().contains(query),
              )
              .toList();
    // A reload with data already on screen keeps the list visible instead of
    // flashing back to the skeleton.
    final showSkeleton = _loading && _mappings.isEmpty;
    final hasList = !showSkeleton && _error == null && _mappings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Learn from Actual',
            onPressed: _learnFromActual,
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      floatingActionButton: hasList
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add mapping'),
            )
          : null,
      body: showSkeleton
          ? const SkeletonRows(count: 6)
          : _error != null
          ? ErrorRetry(title: 'Could not load category memory', message: _error!, onRetry: _load)
          : _mappings.isEmpty
          ? EmptyState(
              icon: Icons.sell_outlined,
              title: 'Nothing remembered yet',
              message:
                  'Categorize a few transactions in Actual, then pull them in here. '
                  'Future statements from the same payees get that category automatically.',
              actionLabel: 'Learn from Actual',
              actionIcon: Icons.sync_rounded,
              onAction: _learnFromActual,
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.xs,
                      Space.gutter,
                      Space.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Matching is exact on the payee text, so slightly different '
                          'merchant strings need their own mapping.',
                          style: context.text.bodySmall,
                        ),
                        const SizedBox(height: Space.lg),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search ${_mappings.length} payees',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.gutter),
                      child: Text(
                        'No payee or category matches "${_query.trim()}".',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(indent: Space.gutter, endIndent: Space.gutter),
                    itemBuilder: (context, index) {
                      final mapping = filtered[index];
                      return _MappingTile(
                        mapping: mapping,
                        onTap: () => _addOrEdit(existing: mapping),
                        onDismissed: () => _delete(mapping),
                      );
                    },
                  ),
                // Clearance so the last row is never hidden under the FAB.
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }
}

class _MappingTile extends StatelessWidget {
  final CategoryMapping mapping;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _MappingTile({required this.mapping, required this.onTap, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dismissible(
      key: ValueKey(mapping.payee),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colors.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Forget',
              style: context.text.labelLarge?.copyWith(color: colors.onErrorContainer),
            ),
            const SizedBox(width: Space.sm),
            Icon(Icons.delete_outline_rounded, color: colors.onErrorContainer),
          ],
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        title: Text(mapping.payee, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Icon(Icons.sell_outlined, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                mapping.categoryName ?? mapping.categoryId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: colors.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

class _MappingEditResult {
  final String payee;
  final String categoryId;
  final String? categoryName;

  const _MappingEditResult({required this.payee, required this.categoryId, this.categoryName});
}

class _MappingEditSheet extends StatefulWidget {
  final CategoryMapping? existing;
  final List<ActualCategoryGroup> categoryGroups;

  const _MappingEditSheet({this.existing, required this.categoryGroups});

  @override
  State<_MappingEditSheet> createState() => _MappingEditSheetState();
}

class _MappingEditSheetState extends State<_MappingEditSheet> {
  late final TextEditingController _payeeController;
  String? _categoryId;
  String? _categoryName;
  String? _payeeError;
  bool _categoryMissing = false;

  @override
  void initState() {
    super.initState();
    _payeeController = TextEditingController(text: widget.existing?.payee ?? '');
    _categoryId = widget.existing?.categoryId;
    _categoryName = widget.existing?.categoryName;
  }

  @override
  void dispose() {
    _payeeController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final choice = await pickCategory(context, widget.categoryGroups);
    if (choice != null) {
      setState(() {
        _categoryId = choice.id;
        _categoryName = choice.name;
        _categoryMissing = false;
      });
    }
  }

  void _save() {
    final payee = _payeeController.text.trim();
    final categoryId = _categoryId;
    if (payee.isEmpty || categoryId == null) {
      setState(() {
        _payeeError = payee.isEmpty ? 'Enter the payee as it appears on statements.' : null;
        _categoryMissing = categoryId == null;
      });
      return;
    }
    Navigator.pop(
      context,
      _MappingEditResult(payee: payee, categoryId: categoryId, categoryName: _categoryName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SheetBody(
      title: editing ? 'Edit mapping' : 'Add mapping',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
      children: [
        LabeledField(
          label: 'Payee',
          helper: editing ? null : 'Exactly as it appears on your statements.',
          child: TextField(
            controller: _payeeController,
            enabled: !editing,
            autofocus: !editing,
            decoration: InputDecoration(errorText: _payeeError),
            onChanged: (_) {
              if (_payeeError != null) setState(() => _payeeError = null);
            },
          ),
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: 'Category',
          child: PickerField(
            leadingIcon: Icons.sell_outlined,
            value: _categoryName ?? 'Choose a category',
            isPlaceholder: _categoryName == null,
            trailingIcon: Icons.chevron_right_rounded,
            onTap: _pickCategory,
          ),
        ),
        if (_categoryMissing) ...[
          const SizedBox(height: Space.xs + 2),
          Text(
            'Choose a category for this payee.',
            style: context.text.bodySmall?.copyWith(color: context.colors.error),
          ),
        ],
      ],
    );
  }
}

class _LearnRequest {
  final String accountId;
  final String startDate;
  final String endDate;

  const _LearnRequest({required this.accountId, required this.startDate, required this.endDate});
}

class _LearnFromActualSheet extends ConsumerStatefulWidget {
  const _LearnFromActualSheet();

  @override
  ConsumerState<_LearnFromActualSheet> createState() => _LearnFromActualSheetState();
}

class _LearnFromActualSheetState extends ConsumerState<_LearnFromActualSheet> {
  List<ActualAccount> _accounts = [];
  ActualAccount? _selectedAccount;
  bool _loading = true;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _end = DateTime.now();
    _start = DateTime(_end.year, _end.month - 3, _end.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      final accounts = await ref.read(importerApiProvider).getAccounts(budgetSyncId: budgetSyncId);
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
        });
      }
    } on ApiException {
      // Leave the list empty; the account field's helper says so.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: _end,
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'Learn from Actual',
      description: 'Remembers the category of every already-categorized transaction in this range.',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selectedAccount == null
              ? null
              : () => Navigator.pop(
                  context,
                  _LearnRequest(
                    accountId: _selectedAccount!.id,
                    startDate: toIsoDate(_start),
                    endDate: toIsoDate(_end),
                  ),
                ),
          child: const Text('Learn'),
        ),
      ],
      children: [
        LabeledField(
          label: 'Account',
          helper: !_loading && _accounts.isEmpty
              ? 'No accounts could be loaded. Check the connection in Settings.'
              : null,
          child: _loading
              ? const Skeleton(height: 52, radius: Radii.control)
              : DropdownButtonFormField<ActualAccount>(
                  initialValue: _selectedAccount,
                  icon: const Icon(Icons.unfold_more_rounded, size: 18),
                  borderRadius: Radii.controlAll,
                  items: _accounts
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                      .toList(),
                  onChanged: (a) => setState(() => _selectedAccount = a),
                ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: LabeledField(
                label: 'From',
                child: PickerField(
                  value: formatDisplayDate(_start),
                  useFigures: true,
                  trailingIcon: Icons.calendar_today_outlined,
                  onTap: _pickStart,
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: LabeledField(
                label: 'To',
                child: PickerField(
                  value: formatDisplayDate(_end),
                  useFigures: true,
                  trailingIcon: Icons.calendar_today_outlined,
                  onTap: _pickEnd,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
