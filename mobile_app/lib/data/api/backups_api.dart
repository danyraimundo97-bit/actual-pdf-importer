import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../models/backup_status.dart';
import 'api_client.dart';

/// The backend's backups (`/backups*`, backend_app/src/backup.ts and
/// backup-schedule.ts; docs/plans/backups.md).
class BackupsApi {
  final ApiClient _client;

  BackupsApi(this._client);

  Dio get _dio => _client.dio;

  Future<BackupStatus> status() async {
    final res = await _guarded(() => _dio.get('/backups'));
    return BackupStatus.fromJson(res.data as Map<String, dynamic>);
  }

  /// Changes the schedule. A budget's `password`: a string keeps it for
  /// backups, null forgets it, absent leaves it as it is.
  Future<BackupSettings> updateSettings({
    BackupFrequency? frequency,
    String? time,
    int? keep,
    List<Map<String, Object?>>? budgets,
  }) async {
    final res = await _guarded(
      () => _dio.put(
        '/backups/settings',
        data: {'frequency': ?frequency?.name, 'time': ?time, 'keep': ?keep, 'budgets': ?budgets},
      ),
    );
    return BackupSettings.fromJson(res.data as Map<String, dynamic>);
  }

  /// Backs up now: app data and every chosen budget, or just one kind.
  Future<({List<BackupRunResult> results, BackupStatus status})> runNow({String? kind, String? budgetSyncId}) async {
    final res = await _guarded(() => _dio.post('/backups', data: {'kind': ?kind, 'budgetSyncId': ?budgetSyncId}));
    final data = res.data as Map<String, dynamic>;
    return (
      results: [for (final r in (data['results'] as List).cast<Map<String, dynamic>>()) BackupRunResult.fromJson(r)],
      status: BackupStatus.fromJson(data['status'] as Map<String, dynamic>),
    );
  }

  /// One backup's bytes, in memory (handed to the share sheet, never saved by the app).
  Future<Uint8List> download(BackupFile backup) async {
    final res = await _guarded(
      () => _dio.get<List<int>>(_path(backup), options: Options(responseType: ResponseType.bytes)),
    );
    return Uint8List.fromList(res.data as List<int>);
  }

  Future<void> delete(BackupFile backup) async {
    await _guarded(() => _dio.delete(_path(backup)));
  }

  /// Restores an app-data backup on the backend (it makes a safety copy first).
  Future<({int mappings, int forgotten})> restoreAppData(BackupFile backup) async {
    final res = await _guarded(() => _dio.post('/backups/app-data/${Uri.encodeComponent(backup.file)}/restore'));
    final data = res.data as Map<String, dynamic>;
    return (mappings: data['mappings'] as int, forgotten: data['forgotten'] as int);
  }

  String _path(BackupFile b) => '/backups/${Uri.encodeComponent(b.folder)}/${Uri.encodeComponent(b.file)}';

  Future<Response<T>> _guarded<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
