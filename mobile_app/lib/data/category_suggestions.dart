import 'models/category_mapping.dart';
import 'models/parsed_transaction.dart';

/// The category memory's lookup key: the same normalisation as the
/// backend's `normalizeKey` (backend_app/src/categorydb.ts), so a payee
/// matches here exactly when it would match in `POST /parse`.
String categoryMemoryKey(String payee) => payee.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Fills `suggestedCategory*` from the category memory, the way `/parse`
/// does: a mapping of the active budget first, then an unscoped one (made
/// before mappings were per budget). Transactions that already have a
/// suggestion keep it.
List<ParsedTransaction> applyCategoryMemory(
  List<ParsedTransaction> transactions, {
  required List<CategoryMapping> scoped,
  List<CategoryMapping> unscoped = const [],
}) {
  final byKey = <String, CategoryMapping>{
    for (final m in unscoped) categoryMemoryKey(m.payee): m,
    // Later entries win, so the budget's own mapping overrides an unscoped one.
    for (final m in scoped) categoryMemoryKey(m.payee): m,
  };
  if (byKey.isEmpty) return transactions;
  return [
    for (final t in transactions)
      switch (byKey[categoryMemoryKey(t.payee)]) {
        final m? when t.suggestedCategoryId == null => t.copyWith(
          suggestedCategoryId: m.categoryId,
          suggestedCategoryName: m.categoryName,
        ),
        _ => t,
      },
  ];
}
