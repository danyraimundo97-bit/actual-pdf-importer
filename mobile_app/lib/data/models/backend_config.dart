class BackendConfig {
  /// "ai" when the backend reads statements (with its AI provider), "off"
  /// when it doesn't. Backends from before the phone read statements also
  /// send "regex" or "both".
  final String parserMode;
  final String? aiProvider;
  final bool aiConfigured;
  final String? defaultBudgetSyncId;

  /// Whether the backend has an Actual server (it's optional). Backends from
  /// before that was optional always had one, so a missing field means yes.
  final bool actualConfigured;

  /// The Actual server is set in the backend's .env, so the app can't change it.
  final bool actualLocked;

  const BackendConfig({
    required this.parserMode,
    this.aiProvider,
    required this.aiConfigured,
    this.defaultBudgetSyncId,
    this.actualConfigured = true,
    this.actualLocked = false,
  });

  /// Whether a statement parsed right now could leave the machine — drives
  /// the privacy banner on the Import screen.
  bool get usesAi => parserMode == 'ai' || parserMode == 'both';

  /// Whether sending a statement to this backend can work at all.
  bool get readsStatements => parserMode != 'off';

  factory BackendConfig.fromJson(Map<String, dynamic> json) {
    return BackendConfig(
      parserMode: json['parserMode'] as String,
      aiProvider: json['aiProvider'] as String?,
      aiConfigured: json['aiConfigured'] as bool,
      defaultBudgetSyncId: json['defaultBudgetSyncId'] as String?,
      actualConfigured: (json['actual'] as Map?)?['configured'] as bool? ?? true,
      actualLocked: (json['actual'] as Map?)?['locked'] as bool? ?? false,
    );
  }
}
