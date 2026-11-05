class ImportResult {
  final int added;
  final int updated;
  final int categorized;

  /// Actual ids of the transactions this import created — what undoing it
  /// deletes. Empty from a backend too old to report them.
  final List<String> addedIds;

  /// Set when the statement was saved on the phone (the local ledger)
  /// instead of imported into Actual: the account it went into. [updated]
  /// then counts lines already on the phone, and [addedIds] are ledger ids.
  final ({String id, String name})? phoneAccount;

  /// Written to the phone's copy of the Actual budget first; the sync takes
  /// it to Actual. [addedIds] are then ledger ids, and undoing goes through
  /// the ledger too.
  final bool inLedger;

  const ImportResult({
    required this.added,
    required this.updated,
    required this.categorized,
    this.addedIds = const [],
    this.phoneAccount,
    this.inLedger = false,
  });

  bool get onPhone => phoneAccount != null;

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      added: json['added'] as int,
      updated: json['updated'] as int,
      categorized: json['categorized'] as int,
      addedIds: (json['addedIds'] as List?)?.cast<String>() ?? const [],
    );
  }
}
