import '../../data/local/db/app_database.dart';
import '../../data/local/ledger_store.dart';
import '../../data/models/parsed_transaction.dart';

// Saving a reviewed statement on the phone (docs/plans/local-ledger.md,
// Phase 3). Pure, so it's tested without widgets.

/// The open account a statement from [bankId] goes into by default: the one
/// that bank's statements last went into, else an account set up for that
/// bank, else the only account. Null when there's a real choice to make.
LedgerAccount? suggestLedgerAccount(List<LedgerAccount> open, {required String bankId, String? lastUsedId}) {
  for (final account in open) {
    if (account.id == lastUsedId) return account;
  }
  for (final account in open) {
    if (account.bankId == bankId) return account;
  }
  return open.length == 1 ? open.single : null;
}

/// The selected lines as ledger drafts. The importedId is the statement's,
/// whatever was edited, so saving the same statement again adds nothing.
///
/// With [keepLines] each keeps its statement line as the note, as an import
/// into Actual always has.
List<LedgerDraft> statementDrafts(List<ParsedTransaction> included, {bool keepLines = false}) => [
  for (final t in included)
    LedgerDraft(
      date: t.date,
      amountCents: t.amountCents,
      payee: t.payee,
      categoryId: t.effectiveCategoryId,
      notes: keepLines ? t.rawLine : null,
      importedId: t.importedId,
    ),
];
