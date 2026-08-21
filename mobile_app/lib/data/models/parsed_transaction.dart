/// Mirrors the backend's transaction shape from POST /parse, plus a few
/// UI-only fields (include/override/edited) that never get sent as-is —
/// see [toConfirmJson].
class ParsedTransaction {
  /// From the "YYYY-MM-DD" string the backend sends. No time-of-day
  /// component, so this is always local midnight — never treat it as a
  /// timestamp.
  final DateTime date;
  final String payee;

  /// Integer cents, negative = outflow. Never a double — see the plan's
  /// note on why money is always an int end to end.
  final int amountCents;
  final String rawLine;

  /// The backend's dedupe id for this line (see actual.ts's
  /// deriveImportedId). MUST be sent back unchanged on import even if
  /// date/payee/amountCents are edited below — it's derived from the
  /// statement's original values, not whatever the user changes them to.
  final String importedId;

  final String? suggestedCategoryId;
  final String? suggestedCategoryName;

  /// UI-only: whether this row is included in the import. Excluded rows
  /// are dropped before the request is built (see toConfirmJson callers).
  final bool include;

  /// UI-only: the user's explicit category choice, overriding the
  /// suggestion. Null means "use the suggestion" (or nothing).
  final String? overrideCategoryId;
  final String? overrideCategoryName;

  /// UI-only: true once the user has changed something about this row.
  /// Drives the "remember this category?" prompt after import.
  final bool edited;

  const ParsedTransaction({
    required this.date,
    required this.payee,
    required this.amountCents,
    required this.rawLine,
    required this.importedId,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.include = true,
    this.overrideCategoryId,
    this.overrideCategoryName,
    this.edited = false,
  });

  String? get effectiveCategoryId => overrideCategoryId ?? suggestedCategoryId;

  String? get effectiveCategoryName =>
      overrideCategoryId != null ? overrideCategoryName : suggestedCategoryName;

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedTransaction(
      date: DateTime.parse(json['date'] as String),
      payee: json['payee'] as String,
      amountCents: json['amountCents'] as int,
      rawLine: json['rawLine'] as String,
      importedId: json['importedId'] as String,
      suggestedCategoryId: json['suggestedCategoryId'] as String?,
      suggestedCategoryName: json['suggestedCategoryName'] as String?,
    );
  }

  /// The shape POST /import/confirm expects for one transaction.
  Map<String, dynamic> toConfirmJson() {
    return {
      'date': _isoDate(date),
      'payee': payee,
      'amountCents': amountCents,
      'rawLine': rawLine,
      'importedId': importedId,
      if (effectiveCategoryId != null) 'categoryId': effectiveCategoryId,
    };
  }

  ParsedTransaction copyWith({
    DateTime? date,
    String? payee,
    int? amountCents,
    String? rawLine,
    String? importedId,
    String? suggestedCategoryId,
    String? suggestedCategoryName,
    bool? include,
    String? overrideCategoryId,
    String? overrideCategoryName,
    bool? edited,
  }) {
    return ParsedTransaction(
      date: date ?? this.date,
      payee: payee ?? this.payee,
      amountCents: amountCents ?? this.amountCents,
      rawLine: rawLine ?? this.rawLine,
      importedId: importedId ?? this.importedId,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestedCategoryName: suggestedCategoryName ?? this.suggestedCategoryName,
      include: include ?? this.include,
      overrideCategoryId: overrideCategoryId ?? this.overrideCategoryId,
      overrideCategoryName: overrideCategoryName ?? this.overrideCategoryName,
      edited: edited ?? this.edited,
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
