class ActualAccount {
  final String id;
  final String name;
  final bool offbudget;
  final bool closed;

  const ActualAccount({
    required this.id,
    required this.name,
    required this.offbudget,
    required this.closed,
  });

  factory ActualAccount.fromJson(Map<String, dynamic> json) {
    return ActualAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      offbudget: json['offbudget'] as bool,
      closed: json['closed'] as bool,
    );
  }
}
