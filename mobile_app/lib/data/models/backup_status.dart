/// The backend's backups as `GET /backups` reports them.
enum BackupFrequency { off, daily, weekly, monthly, yearly }

class BackupBudgetChoice {
  final String syncId;
  final String? name;
  final bool hasPassword;

  const BackupBudgetChoice({required this.syncId, this.name, this.hasPassword = false});

  factory BackupBudgetChoice.fromJson(Map<String, dynamic> json) => BackupBudgetChoice(
    syncId: json['syncId'] as String,
    name: json['name'] as String?,
    hasPassword: json['hasPassword'] as bool? ?? false,
  );

  /// For PUT /backups/settings: the stored password stays unless [password] says otherwise.
  Map<String, Object?> toJson({String? password, bool forgetPassword = false}) => {
    'syncId': syncId,
    'name': ?name,
    if (password != null) 'password': password else if (forgetPassword) 'password': null,
  };
}

class BackupSettings {
  final BackupFrequency frequency;

  /// `HH:MM`, the backend's local time.
  final String time;
  final int keep;
  final List<BackupBudgetChoice> budgets;

  const BackupSettings({required this.frequency, required this.time, required this.keep, required this.budgets});

  factory BackupSettings.fromJson(Map<String, dynamic> json) => BackupSettings(
    frequency: BackupFrequency.values.firstWhere((f) => f.name == json['frequency'], orElse: () => BackupFrequency.off),
    time: json['time'] as String? ?? '03:00',
    keep: json['keep'] as int? ?? 10,
    budgets: [
      for (final b in (json['budgets'] as List? ?? const []).cast<Map<String, dynamic>>())
        BackupBudgetChoice.fromJson(b),
    ],
  );
}

class BackupFile {
  /// `app-data` or a budget's sync id.
  final String folder;
  final String file;
  final int size;
  final DateTime createdAt;
  final bool beforeRestore;

  const BackupFile({
    required this.folder,
    required this.file,
    required this.size,
    required this.createdAt,
    this.beforeRestore = false,
  });

  bool get isAppData => folder == appDataFolder;

  factory BackupFile.fromJson(Map<String, dynamic> json) => BackupFile(
    folder: json['folder'] as String,
    file: json['file'] as String,
    size: json['size'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    beforeRestore: json['beforeRestore'] as bool? ?? false,
  );
}

const appDataFolder = 'app-data';

class BackupLastRun {
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final String? errorCode;
  final String? errorMessage;

  const BackupLastRun({this.lastAttemptAt, this.lastSuccessAt, this.errorCode, this.errorMessage});

  /// The last attempt failed (a later success clears it).
  bool get failed =>
      errorMessage != null &&
      lastAttemptAt != null &&
      (lastSuccessAt == null || lastAttemptAt!.isAfter(lastSuccessAt!));

  factory BackupLastRun.fromJson(Map<String, dynamic> json) {
    DateTime? at(String key) => json[key] is String ? DateTime.parse(json[key] as String).toLocal() : null;
    final error = json['lastError'] as Map<String, dynamic>?;
    return BackupLastRun(
      lastAttemptAt: at('lastAttemptAt'),
      lastSuccessAt: at('lastSuccessAt'),
      errorCode: error?['code'] as String?,
      errorMessage: error?['message'] as String?,
    );
  }
}

class BackupTarget {
  final String folder;
  final String? name;
  final List<BackupFile> backups;
  final BackupLastRun? last;
  final DateTime? nextDue;

  const BackupTarget({required this.folder, this.name, required this.backups, this.last, this.nextDue});

  factory BackupTarget.fromJson(Map<String, dynamic> json) => BackupTarget(
    folder: json['folder'] as String,
    name: json['name'] as String?,
    backups: [
      for (final b in (json['backups'] as List? ?? const []).cast<Map<String, dynamic>>()) BackupFile.fromJson(b),
    ],
    last: json['last'] is Map<String, dynamic> ? BackupLastRun.fromJson(json['last'] as Map<String, dynamic>) : null,
    nextDue: json['nextDue'] is String ? DateTime.parse(json['nextDue'] as String).toLocal() : null,
  );
}

class BackupStatus {
  final BackupSettings settings;
  final bool actualConfigured;
  final BackupTarget appData;
  final List<BackupTarget> budgets;

  const BackupStatus({
    required this.settings,
    required this.actualConfigured,
    required this.appData,
    required this.budgets,
  });

  factory BackupStatus.fromJson(Map<String, dynamic> json) => BackupStatus(
    settings: BackupSettings.fromJson(json['settings'] as Map<String, dynamic>),
    actualConfigured: json['actualConfigured'] as bool? ?? false,
    appData: BackupTarget.fromJson(json['appData'] as Map<String, dynamic>),
    budgets: [
      for (final b in (json['budgets'] as List? ?? const []).cast<Map<String, dynamic>>()) BackupTarget.fromJson(b),
    ],
  );
}

class BackupRunResult {
  final String folder;
  final bool ok;
  final String? errorCode;
  final String? errorMessage;

  const BackupRunResult({required this.folder, required this.ok, this.errorCode, this.errorMessage});

  factory BackupRunResult.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    return BackupRunResult(
      folder: json['folder'] as String,
      ok: json['ok'] as bool? ?? false,
      errorCode: error?['code'] as String?,
      errorMessage: error?['message'] as String?,
    );
  }
}
