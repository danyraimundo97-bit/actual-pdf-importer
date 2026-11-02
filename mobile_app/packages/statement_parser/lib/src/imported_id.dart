/// Dedupe ids. Port of `assignImportedIds` / `deriveImportedId` in
/// `backend_app/src/actual.ts`, and must match it exactly: a different id
/// makes every statement already imported come back as duplicates. Pinned by
/// `fixtures/imported-ids.json`, shared with the backend's tests.
library;

/// Every `imported_id` the importer writes starts with this; undoing an
/// import relies on it.
const importedIdPrefix = 'pdfimport-';

String _basisOf(String date, int amountCents, String payee) => '$date|$amountCents|$payee';

/// The same hash as the backend: `hash = (hash * 31 + charCode) | 0` per
/// UTF-16 code unit. `toSigned(32)` reproduces JavaScript's `| 0`.
String _derive(String basis, int occurrence) {
  final input = occurrence == 0 ? basis : '$basis|#$occurrence';
  var hash = 0;
  for (var i = 0; i < input.length; i++) {
    hash = (hash * 31 + input.codeUnitAt(i)).toSigned(32);
  }
  return '$importedIdPrefix$hash';
}

/// Dedupe ids for a whole statement, in order.
///
/// Date + amount + payee is not unique within a statement (banks truncate
/// payees; two equal transfers on one day are ordinary), so repeats of a
/// basis are numbered as they're found: occurrence 0 hashes the bare basis,
/// later ones add `|#n`. Only meaningful over the whole statement, never
/// per transaction.
///
/// [existing] holds ids already issued (e.g. kept through edits on the
/// review screen), by index; those are kept as-is but still counted as
/// repeats, so the rest are numbered exactly as the first pass did.
List<String> assignImportedIds(
  List<({String date, int amountCents, String payee})> transactions, {
  Map<int, String> existing = const {},
}) {
  final occurrences = <String, int>{};
  return [
    for (var i = 0; i < transactions.length; i++)
      () {
        final t = transactions[i];
        final basis = _basisOf(t.date, t.amountCents, t.payee);
        final occurrence = occurrences[basis] ?? 0;
        occurrences[basis] = occurrence + 1;
        return existing[i] ?? _derive(basis, occurrence);
      }(),
  ];
}
