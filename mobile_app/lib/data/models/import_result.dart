class ImportResult {
  final int added;
  final int updated;
  final int categorized;

  const ImportResult({required this.added, required this.updated, required this.categorized});

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      added: json['added'] as int,
      updated: json['updated'] as int,
      categorized: json['categorized'] as int,
    );
  }
}
