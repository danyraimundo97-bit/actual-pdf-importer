import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished import, as shown under "Recent imports". Metadata only:
/// the statement itself is never stored (PDFs stay in memory, see
/// InboxController).
class ImportHistoryEntry {
  final String filename;
  final String bankId;
  final String accountName;
  final int added;
  final int updated;
  final DateTime at;

  const ImportHistoryEntry({
    required this.filename,
    required this.bankId,
    required this.accountName,
    required this.added,
    required this.updated,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'bankId': bankId,
    'accountName': accountName,
    'added': added,
    'updated': updated,
    'at': at.toIso8601String(),
  };

  factory ImportHistoryEntry.fromJson(Map<String, dynamic> json) => ImportHistoryEntry(
    filename: json['filename'] as String,
    bankId: json['bankId'] as String,
    accountName: json['accountName'] as String,
    added: json['added'] as int,
    updated: json['updated'] as int,
    at: DateTime.parse(json['at'] as String),
  );
}

class ImportHistoryStore {
  static const _kHistory = 'import_history';
  static const maxEntries = 20;

  final SharedPreferences _prefs;

  const ImportHistoryStore(this._prefs);

  List<ImportHistoryEntry> read() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ImportHistoryEntry.fromJson)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> write(List<ImportHistoryEntry> entries) =>
      _prefs.setString(_kHistory, jsonEncode(entries.map((e) => e.toJson()).toList()));
}

/// Newest first, capped at [ImportHistoryStore.maxEntries].
class ImportHistoryController extends StateNotifier<List<ImportHistoryEntry>> {
  final ImportHistoryStore _store;

  ImportHistoryController(this._store) : super(_store.read());

  Future<void> add(ImportHistoryEntry entry) async {
    state = [entry, ...state].take(ImportHistoryStore.maxEntries).toList();
    await _store.write(state);
  }

  /// Re-reads after the dev page clears preferences.
  void reload() => state = _store.read();
}
