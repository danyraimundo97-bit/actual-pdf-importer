/// GET/PUT/DELETE /actual/connection: the backend's link to an Actual
/// server, which is optional. The password never comes back, only whether
/// one is set.
class ActualConnection {
  final bool configured;

  /// Set in the backend's .env: shown, but the app can't change it.
  final bool locked;
  final String? serverUrl;
  final bool hasPassword;

  /// Only after a successful connect (the backend checks it then).
  final String? serverVersion;

  const ActualConnection({
    required this.configured,
    required this.locked,
    this.serverUrl,
    this.hasPassword = false,
    this.serverVersion,
  });

  factory ActualConnection.fromJson(Map<String, dynamic> json) => ActualConnection(
        configured: json['configured'] as bool? ?? false,
        locked: json['locked'] as bool? ?? false,
        serverUrl: json['serverUrl'] as String?,
        hasPassword: json['hasPassword'] as bool? ?? false,
        serverVersion: json['serverVersion'] as String?,
      );
}
