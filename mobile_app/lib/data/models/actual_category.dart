class ActualCategory {
  final String id;
  final String name;

  const ActualCategory({required this.id, required this.name});

  factory ActualCategory.fromJson(Map<String, dynamic> json) {
    return ActualCategory(id: json['id'] as String, name: json['name'] as String);
  }
}

class ActualCategoryGroup {
  final String id;
  final String name;
  final List<ActualCategory> categories;

  const ActualCategoryGroup({required this.id, required this.name, required this.categories});

  factory ActualCategoryGroup.fromJson(Map<String, dynamic> json) {
    final rawCategories = (json['categories'] as List? ?? const []).cast<Map<String, dynamic>>();
    return ActualCategoryGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      categories: rawCategories.map(ActualCategory.fromJson).toList(),
    );
  }
}
