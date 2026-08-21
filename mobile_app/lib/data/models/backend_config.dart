class BackendConfig {
  final String parserMode; // 'regex' | 'ai' | 'both'
  final String? aiProvider;
  final bool aiConfigured;
  final String? defaultBudgetSyncId;

  const BackendConfig({
    required this.parserMode,
    this.aiProvider,
    required this.aiConfigured,
    this.defaultBudgetSyncId,
  });

  /// Whether a statement parsed right now could leave the machine — drives
  /// the privacy banner on the Import screen.
  bool get usesAi => parserMode == 'ai' || parserMode == 'both';

  factory BackendConfig.fromJson(Map<String, dynamic> json) {
    return BackendConfig(
      parserMode: json['parserMode'] as String,
      aiProvider: json['aiProvider'] as String?,
      aiConfigured: json['aiConfigured'] as bool,
      defaultBudgetSyncId: json['defaultBudgetSyncId'] as String?,
    );
  }
}
