import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/import_result.dart';
import '../../data/models/parse_result.dart';
import '../../data/providers.dart';

/// The backend rejects statements above this size; checking locally gives
/// an immediate, specific error instead of a failed upload.
const maxStatementBytes = 20 * 1024 * 1024;

enum InboxStatus { queued, parsing, needsPassword, ready, imported, failed }

class InboxItem {
  final int id;
  final String filename;
  final Uint8List bytes;
  final InboxStatus status;
  final ParseResult? parseResult;
  final ImportResult? importResult;
  final String? error;

  /// True when the last password attempt was rejected.
  final bool wrongPassword;

  const InboxItem({
    required this.id,
    required this.filename,
    required this.bytes,
    this.status = InboxStatus.queued,
    this.parseResult,
    this.importResult,
    this.error,
    this.wrongPassword = false,
  });

  int get sizeBytes => bytes.length;

  InboxItem copyWith({
    InboxStatus? status,
    ParseResult? parseResult,
    ImportResult? importResult,
    String? error,
    bool? wrongPassword,
    bool clearError = false,
  }) {
    return InboxItem(
      id: id,
      filename: filename,
      bytes: bytes,
      status: status ?? this.status,
      parseResult: parseResult ?? this.parseResult,
      importResult: importResult ?? this.importResult,
      error: clearError ? null : (error ?? this.error),
      wrongPassword: wrongPassword ?? this.wrongPassword,
    );
  }
}

/// Statements waiting to be parsed, reviewed and imported. Lives in memory
/// only: PDF bytes are never written to disk on the phone, matching the
/// backend's memory-only upload handling. Parses one statement at a time,
/// in the order they were added.
class InboxController extends Notifier<List<InboxItem>> {
  int _nextId = 1;
  bool _pumping = false;

  @override
  List<InboxItem> build() => const [];

  void add({required String filename, required Uint8List bytes}) {
    final item = InboxItem(id: _nextId++, filename: filename, bytes: bytes);
    state = [
      ...state,
      bytes.length > maxStatementBytes
          ? item.copyWith(
              status: InboxStatus.failed,
              error: 'Larger than 20 MB, which is the most the importer accepts.',
            )
          : item,
    ];
    _pump();
  }

  void remove(int id) => state = state.where((i) => i.id != id).toList();

  /// Drops imported and failed items, keeping anything still in progress.
  void clearFinished() => state = state
      .where((i) => i.status != InboxStatus.imported && i.status != InboxStatus.failed)
      .toList();

  /// Re-queues a failed item, or retries a locked one with [password].
  void retry(int id, {String? password}) {
    final item = _find(id);
    if (item == null) return;
    if (password != null) {
      _parse(item, password: password);
    } else {
      _update(id, (i) => i.copyWith(status: InboxStatus.queued, clearError: true));
      _pump();
    }
  }

  void markImported(int id, ImportResult result) {
    _update(id, (i) => i.copyWith(status: InboxStatus.imported, importResult: result));
  }

  InboxItem? _find(int id) {
    for (final item in state) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _update(int id, InboxItem Function(InboxItem) change) {
    state = [for (final item in state) item.id == id ? change(item) : item];
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        InboxItem? next;
        for (final item in state) {
          if (item.status == InboxStatus.queued) {
            next = item;
            break;
          }
        }
        if (next == null) break;
        await _parse(next);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _parse(InboxItem item, {String? password}) async {
    _update(item.id, (i) => i.copyWith(status: InboxStatus.parsing, clearError: true));
    try {
      final result = await ref
          .read(importerApiProvider)
          .parseStatement(
            bytes: item.bytes,
            filename: item.filename,
            password: password,
            budgetSyncId: ref.read(appConfigProvider).budgetSyncId,
          );
      _update(
        item.id,
        (i) => i.copyWith(status: InboxStatus.ready, parseResult: result, wrongPassword: false),
      );
    } on ApiException catch (e) {
      if (e.code == 'PDF_PASSWORD_REQUIRED' || e.code == 'PDF_PASSWORD_INCORRECT') {
        _update(
          item.id,
          (i) => i.copyWith(
            status: InboxStatus.needsPassword,
            wrongPassword: e.code == 'PDF_PASSWORD_INCORRECT',
          ),
        );
      } else {
        final message = switch (e.code) {
          'BANK_UNRECOGNIZED' => '${e.message} This bank or layout may not be supported yet.',
          _ when e.isUnauthorized => 'The importer rejected the access token. Check Settings.',
          _ => e.message,
        };
        _update(item.id, (i) => i.copyWith(status: InboxStatus.failed, error: message));
      }
    }
  }
}

final inboxProvider = NotifierProvider<InboxController, List<InboxItem>>(InboxController.new);
