class ImportResult {
  final int added;
  final int updated;
  final int categorized;

  /// Actual ids of the transactions this import created — what undoing it
  /// deletes. Empty from a backend too old to report them.
  final List<String> addedIds;

  const ImportResult({
    required this.added,
    required this.updated,
    required this.categorized,
    this.addedIds = const [],
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      added: json['added'] as int,
      updated: json['updated'] as int,
      categorized: json['categorized'] as int,
      addedIds: (json['addedIds'] as List?)?.cast<String>() ?? const [],
    );
  }
}
