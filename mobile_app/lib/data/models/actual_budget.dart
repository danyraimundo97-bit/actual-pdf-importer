class ActualBudget {
  final String syncId;
  final String name;

  /// Actual's own end-to-end encryption for this budget file — unrelated
  /// to a bank statement's PDF password. See SecretStore.budgetPassword.
  final bool encrypted;

  const ActualBudget({required this.syncId, required this.name, required this.encrypted});

  factory ActualBudget.fromJson(Map<String, dynamic> json) {
    return ActualBudget(
      syncId: json['syncId'] as String,
      name: json['name'] as String,
      encrypted: json['encrypted'] as bool,
    );
  }
}
