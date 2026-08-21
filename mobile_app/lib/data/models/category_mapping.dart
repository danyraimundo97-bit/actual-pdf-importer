class CategoryMapping {
  final String payee;
  final String categoryId;
  final String? categoryName;
  final String updatedAt;

  const CategoryMapping({
    required this.payee,
    required this.categoryId,
    this.categoryName,
    required this.updatedAt,
  });

  factory CategoryMapping.fromJson(Map<String, dynamic> json) {
    return CategoryMapping(
      payee: json['payee'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String?,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
