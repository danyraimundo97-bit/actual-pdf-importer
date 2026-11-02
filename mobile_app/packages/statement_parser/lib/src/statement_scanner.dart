/// Shared line scanner. Port of `backend_app/src/parsers/statement-scanner.ts`.
///
/// A movement starts at a date line and owns every line after it until the
/// next date line: long descriptions wrap and the amount can land on a line
/// of its own. Each bank also repeats a page header or footer that can fall
/// in the middle of a movement.
///
/// Works the same on both text shapes: pdf.js (the backend) splits a table
/// row over several lines, PDFium (the app) usually keeps it on the date line
/// itself. Parsers read the date line's own capture groups for that.
library;

class MovementBlock {
  /// The date line, trimmed, for composing `RawTransaction.rawLine`.
  final String dateLine;

  /// The date line's match, so a parser can read its own capture groups.
  final RegExpMatch date;

  /// Trimmed, non-empty lines belonging to this movement.
  final List<String> lines = [];

  MovementBlock(this.dateLine, this.date);
}

class ScanConfig {
  /// Starts a new movement.
  final RegExp dateLine;

  /// Ignore everything before this line matches. Null scans from the top.
  final RegExp? startAt;

  /// Stop at the first line that matches. Null scans to the end.
  final RegExp? endAt;

  /// A repeated page header/footer to skip, as (entering, leaving).
  final (RegExp, RegExp)? skipRegion;

  const ScanConfig({required this.dateLine, this.startAt, this.endAt, this.skipRegion});
}

List<MovementBlock> scanMovementBlocks(String fullText, ScanConfig config) {
  final blocks = <MovementBlock>[];
  MovementBlock? current;
  var awaiting = config.startAt;
  var inRegion = false;
  final region = config.skipRegion;

  for (final rawLine in fullText.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (awaiting != null) {
      if (awaiting.hasMatch(line)) awaiting = null;
      continue;
    }
    if (config.endAt?.hasMatch(line) ?? false) break;

    final date = config.dateLine.firstMatch(line);

    if (region != null) {
      if (inRegion) {
        if (region.$2.hasMatch(line)) {
          inRegion = false;
          continue;
        }
        // Region markers are heuristics a wrapped description can trip
        // (moey's page code looks exactly like the payee "IFTHEN25"). A date
        // line is unambiguous proof the region has ended, so it wins: a
        // missed exit marker costs one movement, never the rest.
        if (date == null) continue;
        inRegion = false;
      }
      if (region.$1.hasMatch(line)) {
        inRegion = true;
        continue;
      }
    }

    if (date != null) {
      current = MovementBlock(line, date);
      blocks.add(current);
    } else {
      current?.lines.add(line);
    }
  }

  return blocks;
}
