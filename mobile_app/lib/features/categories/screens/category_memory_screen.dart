import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../data/models/actual_account.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/category_mapping.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/error_retry.dart';

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
      setState(() => _mappings.removeWhere((m) => m.payee == mapping.payee));
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
            content: Text('Learned ${outcome.learned} mappings from ${outcome.scanned} transactions.'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Learn from Actual',
            onPressed: _learnFromActual,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (_mappings.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nothing remembered yet. Categorize a few transactions in Actual, then '
                          'use "Learn from Actual" to pull them in.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final mapping = filtered[index];
                        return Dismissible(
                          key: ValueKey(mapping.payee),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_outline),
                          ),
                          onDismissed: (_) => _delete(mapping),
                          child: ListTile(
                            title: Text(mapping.payee),
                            subtitle: Text(mapping.categoryName ?? mapping.categoryId),
                            onTap: () => _addOrEdit(existing: mapping),
                          ),
                        );
                      },
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Matching is exact on the payee text — not fuzzy. Slightly different '
                    'merchant strings need their own mapping.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
      });
    }
  }

  void _save() {
    final payee = _payeeController.text.trim();
    final categoryId = _categoryId;
    if (payee.isEmpty || categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a payee and choose a category.')));
      return;
    }
    Navigator.pop(
      context,
      _MappingEditResult(payee: payee, categoryId: categoryId, categoryName: _categoryName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Add mapping' : 'Edit mapping',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payeeController,
            enabled: widget.existing == null,
            decoration: const InputDecoration(labelText: 'Payee'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_categoryName ?? 'Choose a category'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickCategory,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
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
      final accounts = await ref
          .read(importerApiProvider)
          .getAccounts(budgetSyncId: budgetSyncId);
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
        });
      }
    } on ApiException {
      // Leave the list empty; the sheet still shows the date pickers.
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learn from Actual', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Pulls already-categorized transactions from Actual and remembers their '
            'payee -> category.',
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<ActualAccount>(
              value: _selectedAccount,
              decoration: const InputDecoration(labelText: 'Account'),
              items: _accounts
                  .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                  .toList(),
              onChanged: (a) => setState(() => _selectedAccount = a),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('From ${formatDisplayDate(_start)}'),
                  onTap: _pickStart,
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('To ${formatDisplayDate(_end)}'),
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
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
          ),
        ],
      ),
    );
  }
}
