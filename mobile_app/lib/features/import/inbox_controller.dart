import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:statement_parser/statement_parser.dart' show StatementParseResult;

import '../../core/errors/api_exception.dart';
import '../../core/log/app_log.dart';
import '../../data/category_suggestions.dart';
import '../../data/local/db/local_category_store.dart';
import '../../data/models/import_result.dart';
import '../../data/models/parse_result.dart';
import '../../data/models/parsed_transaction.dart';
import '../../data/pdf/pdf_text_extractor.dart';
import '../../data/providers.dart';
import '../categories/category_matching.dart';

/// The backend rejects statements above this size; checking locally gives
/// an immediate, specific error instead of a failed upload.
const maxStatementBytes = 20 * 1024 * 1024;

const _log = AppLog('import');

enum InboxStatus {
  queued,
  parsing,
  needsPassword,

  /// Read on the device, but no built-in parser recognised it (or it found
  /// no movements). The backend's AI parser can try, if the user agrees to
  /// send the PDF there: see [InboxController.sendToBackend].
  unrecognized,
  ready,
  imported,
  failed,
}

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

  /// The password that opened this PDF, kept (in memory only, like the
  /// bytes) so sending it to the AI parser doesn't ask again.
  final String? password;

  /// For [InboxStatus.unrecognized]: the bank a built-in parser recognised
  /// even though it found no movements, or null when none recognised it.
  final String? recognizedBank;

  /// True when [parseResult] came from the on-device parser, false when it
  /// came from the backend.
  final bool parsedOnDevice;

  const InboxItem({
    required this.id,
    required this.filename,
    required this.bytes,
    this.status = InboxStatus.queued,
    this.parseResult,
    this.importResult,
    this.error,
    this.wrongPassword = false,
    this.password,
    this.recognizedBank,
    this.parsedOnDevice = false,
  });

  int get sizeBytes => bytes.length;

  InboxItem copyWith({
    InboxStatus? status,
    ParseResult? parseResult,
    ImportResult? importResult,
    String? error,
    bool? wrongPassword,
    String? password,
    String? recognizedBank,
    bool? parsedOnDevice,
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
      password: password ?? this.password,
      recognizedBank: recognizedBank ?? this.recognizedBank,
      parsedOnDevice: parsedOnDevice ?? this.parsedOnDevice,
    );
  }
}

/// Statements waiting to be parsed, reviewed and imported. Lives in memory
/// only: PDF bytes are never written to disk on the phone, matching the
/// backend's memory-only upload handling. Parses one statement at a time,
/// in the order they were added.
///
/// Statements are read on the device (docs/plans/dart-parser.md, Phase 5)
/// unless the user turned that off in Settings. The PDF only goes to the
/// backend when parsing there is the setting, or when the user asks for the
/// AI parser on a statement the device couldn't read.
class InboxController extends Notifier<List<InboxItem>> {
  int _nextId = 1;
  bool _pumping = false;

  @override
  List<InboxItem> build() => const [];

  void add({required String filename, required Uint8List bytes}) {
    final item = InboxItem(id: _nextId++, filename: filename, bytes: bytes);
    final tooLarge = bytes.length > maxStatementBytes;
    if (tooLarge) {
      _log.warn('Statement rejected: too large', {'item': item.id, 'sizeKb': bytes.length ~/ 1024});
    } else {
      _log.info('Statement queued', {'item': item.id, 'sizeKb': bytes.length ~/ 1024});
    }
    state = [
      ...state,
      tooLarge
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

  /// Sends an [InboxStatus.unrecognized] statement to the backend's
  /// parser (the AI parser, for a bank the device doesn't know). Explicit,
  /// because the PDF leaves the phone.
  void sendToBackend(int id) {
    final item = _find(id);
    if (item == null || item.status != InboxStatus.unrecognized) return;
    _log.info('Statement sent to the backend parser', {'item': id});
    _parseOnBackend(item, password: item.password);
  }

  void markImported(int id, ImportResult result) {
    _log.info('Statement imported', {
      'item': id,
      'added': result.added,
      'updated': result.updated,
      'categorized': result.categorized,
    });
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
    if (ref.read(parseOnDeviceProvider)) {
      await _parseOnDevice(item, password: password);
    } else {
      await _parseOnBackend(item, password: password);
    }
  }

  bool get _hasBackend => ref.read(appConfigProvider).backendUrl?.isNotEmpty ?? false;

  Future<void> _parseOnDevice(InboxItem item, {String? password}) async {
    _update(item.id, (i) => i.copyWith(status: InboxStatus.parsing, clearError: true));
    try {
      final local = await ref.read(localStatementReaderProvider).read(item.bytes, password: password);
      if (!local.recognised || local.transactions.isEmpty) {
        _log.info('Statement not recognised on device', {'item': item.id, 'bank': local.bankId});
        _update(
          item.id,
          (i) => i.copyWith(
            status: InboxStatus.unrecognized,
            password: password,
            recognizedBank: local.bankId,
            wrongPassword: false,
          ),
        );
        return;
      }
      final (transactions, localCategories) = await _withSuggestions(_fromLocal(local));
      final result = ParseResult(
        bankId: local.bankId!,
        transactions: transactions,
        localCategories: localCategories,
      );
      _logParsed(item, result, onDevice: true);
      _update(
        item.id,
        (i) => i.copyWith(
          status: InboxStatus.ready,
          parseResult: result,
          parsedOnDevice: true,
          password: password,
          wrongPassword: false,
        ),
      );
    } on PdfReadException catch (e) {
      _log.warn('Statement not read on device', {'item': item.id, 'code': e.code});
      switch (e.failure) {
        case PdfReadFailure.passwordRequired || PdfReadFailure.passwordIncorrect:
          _update(
            item.id,
            (i) => i.copyWith(
              status: InboxStatus.needsPassword,
              wrongPassword: e.failure == PdfReadFailure.passwordIncorrect,
            ),
          );
        case PdfReadFailure.unreadable:
          _update(
            item.id,
            (i) => i.copyWith(status: InboxStatus.failed, error: "This file isn't a PDF that can be read."),
          );
      }
    } catch (e, st) {
      _crashed(item, e, st);
    }
  }

  static List<ParsedTransaction> _fromLocal(StatementParseResult local) => [
    for (final t in local.transactions)
      ParsedTransaction(
        date: DateTime.parse(t.date),
        payee: t.payee,
        amountCents: t.amountCents,
        rawLine: t.rawLine,
        importedId: t.importedId,
      ),
  ];

  /// Suggested categories, and whether they are the app's own (true) or
  /// Actual's (false).
  ///
  /// With Actual connected: the backend's category memory, which holds
  /// Actual's ids. Only the mappings are fetched; the statement stays on the
  /// device. Otherwise (no backend, no Actual, or the backend doesn't
  /// answer): the phone's own memory, then merchant hints, with the app's
  /// predefined and user categories.
  Future<(List<ParsedTransaction>, bool)> _withSuggestions(List<ParsedTransaction> transactions) async {
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    if (await _actualReady()) {
      try {
        final api = ref.read(categoriesApiProvider);
        final scoped = await api.list(budgetSyncId: budgetSyncId);
        // GET /categories without a budget is the unscoped bucket.
        final unscoped = budgetSyncId == null ? const <Never>[] : await api.list();
        final fromBackend = applyCategoryMemory(transactions, scoped: scoped, unscoped: unscoped);
        return (await _fillFromPhone(fromBackend, budgetSyncId!), false);
      } on ApiException catch (e) {
        _log.warn("Category memory unavailable; using the phone's", {'code': e.code, 'status': e.statusCode});
      }
    }
    final store = ref.read(localCategoryStoreProvider);
    return (
      [
        for (final t in transactions)
          switch (await store.suggest(t.payee, budgetSyncId: budgetSyncId)) {
            final s? => t.copyWith(
              suggestedCategoryId: s.categoryId,
              suggestedCategoryName: s.categoryName,
              suggestedFromHint: s.source == SuggestionSource.hint,
            ),
            null => t,
          },
      ],
      true,
    );
  }

  /// With Actual connected, lines the backend's memory doesn't know can still
  /// get a category from the phone's memory or a hint, when that local
  /// category is linked to an Actual one ("Match your categories"). Unlinked
  /// ones stay uncategorised: Actual can't resolve the app's ids.
  Future<List<ParsedTransaction>> _fillFromPhone(List<ParsedTransaction> transactions, String budgetSyncId) async {
    if (transactions.every((t) => t.suggestedCategoryId != null)) return transactions;
    final store = ref.read(localCategoryStoreProvider);
    final links = await store.links(budgetSyncId);
    if (links.isEmpty) return transactions;
    final Map<String, String> names;
    try {
      names = actualCategoryNames(
        await ref.read(importerApiProvider).getActualCategories(budgetSyncId: budgetSyncId),
      );
    } on ApiException catch (e) {
      _log.warn('Actual categories unavailable; no suggestions from the phone', {'code': e.code});
      return transactions;
    }
    return [
      for (final t in transactions)
        if (t.suggestedCategoryId != null)
          t
        else
          switch (await store.suggest(t.payee, budgetSyncId: budgetSyncId)) {
            final s? => toActualCategories(
              t.copyWith(
                suggestedCategoryId: s.categoryId,
                suggestedCategoryName: s.categoryName,
                suggestedFromHint: s.source == SuggestionSource.hint,
              ),
              links: links,
              actualNames: names,
            ),
            null => t,
          },
    ];
  }

  /// Whether Actual is connected with a budget chosen. A backend that
  /// doesn't answer counts as not connected.
  Future<bool> _actualReady() async {
    if (!_hasBackend) return false;
    // Listened, not just read: the provider is autoDispose and would
    // otherwise be torn down while its request is still running.
    final link = ref.listen(linkStateProvider.future, (_, _) {});
    try {
      return await link.read() == LinkState.ready;
    } catch (_) {
      return false;
    } finally {
      link.close();
    }
  }

  Future<void> _parseOnBackend(InboxItem item, {String? password}) async {
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
      _logParsed(item, result, onDevice: false);
      _update(
        item.id,
        (i) => i.copyWith(status: InboxStatus.ready, parseResult: result, parsedOnDevice: false, wrongPassword: false),
      );
    } on ApiException catch (e) {
      _log.warn('Statement not parsed', {'item': item.id, 'code': e.code, 'status': e.statusCode});
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
    } catch (e, st) {
      _crashed(item, e, st);
    }
  }

  void _logParsed(InboxItem item, ParseResult result, {required bool onDevice}) {
    _log.info('Statement parsed', {
      'item': item.id,
      'onDevice': onDevice,
      'bank': result.bankId,
      'transactions': result.transactions.length,
      'withSuggestion': result.transactions.where((t) => t.suggestedCategoryId != null).length,
    });
    if (Logs.debugEnabled) {
      for (final (index, t) in result.transactions.indexed) {
        _log.debug('Parsed transaction', {
          'item': item.id,
          'n': index,
          'date': t.date.toIso8601String().substring(0, 10),
          'payee': t.payee,
          'importedId': t.importedId,
          'categoryId': t.suggestedCategoryId,
        });
      }
    }
  }

  /// A bug, not a backend answer: record it and fail this item instead of
  /// leaving it stuck on "parsing".
  void _crashed(InboxItem item, Object e, StackTrace st) {
    _log.error('Parsing a statement crashed', e, st, {'item': item.id});
    _update(
      item.id,
      (i) => i.copyWith(status: InboxStatus.failed, error: 'Something went wrong. See Settings → Diagnostics.'),
    );
  }
}

final inboxProvider = NotifierProvider<InboxController, List<InboxItem>>(InboxController.new);
