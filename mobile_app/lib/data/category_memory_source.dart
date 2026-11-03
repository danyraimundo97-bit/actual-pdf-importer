import 'api/categories_api.dart';
import 'api/importer_api.dart';
import 'local/db/local_category_store.dart';
import 'models/actual_category.dart';
import 'models/category_mapping.dart';

/// The category memory the Category memory screen shows: the backend's,
/// holding Actual's categories, while Actual is connected; otherwise the
/// phone's own, with the app's categories. Same operations either way.
abstract interface class CategoryMemorySource {
  /// The phone's memory (true) or the backend's (false).
  bool get isLocal;

  Future<List<CategoryMapping>> list();

  /// The categories a mapping can point to.
  Future<List<ActualCategoryGroup>> categoryGroups();

  Future<void> upsert({required String payee, required String categoryId, String? categoryName});

  Future<void> delete(String payee);

  /// Forgets every mapping of this budget. Returns how many.
  Future<int> clear();
}

class BackendCategoryMemory implements CategoryMemorySource {
  BackendCategoryMemory(this._categories, this._importer, this._budgetSyncId);

  final CategoriesApi _categories;
  final ImporterApi _importer;
  final String? _budgetSyncId;

  @override
  bool get isLocal => false;

  @override
  Future<List<CategoryMapping>> list() => _categories.list(budgetSyncId: _budgetSyncId);

  @override
  Future<List<ActualCategoryGroup>> categoryGroups() => _importer.getActualCategories(budgetSyncId: _budgetSyncId);

  @override
  Future<void> upsert({required String payee, required String categoryId, String? categoryName}) =>
      _categories.upsert(payee: payee, categoryId: categoryId, categoryName: categoryName, budgetSyncId: _budgetSyncId);

  @override
  Future<void> delete(String payee) => _categories.delete(payee, budgetSyncId: _budgetSyncId);

  @override
  Future<int> clear() => _categories.clear(budgetSyncId: _budgetSyncId);
}

class LocalCategoryMemory implements CategoryMemorySource {
  LocalCategoryMemory(this._store, this._budgetSyncId);

  final LocalCategoryStore _store;
  final String? _budgetSyncId;

  @override
  bool get isLocal => true;

  @override
  Future<List<CategoryMapping>> list() async => [
    for (final m in await _store.mappings(budgetSyncId: _budgetSyncId))
      CategoryMapping(payee: m.payee, categoryId: m.categoryId, categoryName: m.categoryName, updatedAt: m.updatedAt),
  ];

  @override
  Future<List<ActualCategoryGroup>> categoryGroups() => _store.groups(budgetSyncId: _budgetSyncId);

  @override
  Future<void> upsert({required String payee, required String categoryId, String? categoryName}) =>
      _store.remember(payee, categoryId, budgetSyncId: _budgetSyncId);

  @override
  Future<void> delete(String payee) => _store.forget(payee, budgetSyncId: _budgetSyncId);

  @override
  Future<int> clear() => _store.clear(budgetSyncId: _budgetSyncId);
}
