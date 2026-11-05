import 'actual_account.dart';
import 'actual_category.dart';

/// GET /quick-add/options: everything the quick-add form needs.
class QuickAddOptions {
  final List<ActualAccount> accounts;
  final List<ActualCategoryGroup> categoryGroups;

  /// Group ids that hold income categories (for the category picker).
  final Set<String> incomeGroupIds;

  /// Most recently used first.
  final List<RecentPayee> recentPayees;

  const QuickAddOptions({
    required this.accounts,
    required this.categoryGroups,
    required this.incomeGroupIds,
    required this.recentPayees,
  });

  factory QuickAddOptions.fromJson(Map<String, dynamic> json) {
    final groups = (json['categoryGroups'] as List? ?? const []).cast<Map<String, dynamic>>();
    return QuickAddOptions(
      accounts: (json['accounts'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((a) => ActualAccount(
                id: a['id'] as String,
                name: a['name'] as String,
                offbudget: a['offbudget'] as bool? ?? false,
                closed: false,
              ))
          .toList(),
      categoryGroups: groups.map(ActualCategoryGroup.fromJson).toList(),
      incomeGroupIds: {
        for (final g in groups)
          if (g['isIncome'] == true) g['id'] as String,
      },
      recentPayees: (json['recentPayees'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((p) => RecentPayee(name: p['name'] as String, lastCategoryId: p['lastCategoryId'] as String?))
          .toList(),
    );
  }

  /// The category's emoji, or null if it has none or isn't visible.
  String? categoryEmoji(String? id) {
    for (final group in categoryGroups) {
      for (final c in group.categories) {
        if (c.id == id) return c.emoji;
      }
    }
    return null;
  }

  /// The category's name, or null if it's not (or no longer) visible.
  String? categoryName(String? id) {
    if (id == null) return null;
    for (final group in categoryGroups) {
      for (final c in group.categories) {
        if (c.id == id) return c.name;
      }
    }
    return null;
  }
}

class RecentPayee {
  final String name;
  final String? lastCategoryId;

  const RecentPayee({required this.name, this.lastCategoryId});
}
