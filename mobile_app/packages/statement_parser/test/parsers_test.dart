import 'dart:io';

import 'package:statement_parser/statement_parser.dart';
import 'package:test/test.dart';

String fixture(String name) => File('../../../fixtures/parsers/$name.txt').readAsStringSync();

int sum(Iterable<RawTransaction> txs) => txs.fold(0, (total, t) => total + t.amountCents);

void main() {
  group('bank detection', () {
    test('each fixture is claimed by its own parser only', () {
      for (final (name, bank) in [
        ('activobank-basic.pdfjs', 'activobank'),
        ('moey-basic.pdfjs', 'moey'),
        ('traderepublic-basic.pdfjs', 'traderepublic'),
      ]) {
        final claims = bankParsers.where((p) => p.canParse(fixture(name))).map((p) => p.bankId);
        expect(claims, [bank], reason: name);
      }
    });

    test('ActivoBank: merely mentioned as a transfer payee is not enough', () {
      expect(const ActivoBankParser().canParse('01-07-2026 Trf imediata ACTIVOBANK 10,00 -10,00'), isFalse);
    });

    test('Trade Republic: a moey row naming it as a payee is not enough', () {
      expect(const TradeRepublicParser().canParse('07-07-2026 TRANSF SEPA -Trade Republic Ba 100,00 +102,90'), isFalse);
    });

    test('unrecognised text gives no bank and no transactions', () {
      final result = parseStatementText('Some other bank\n01-01-2026 COFFEE 2,50');
      expect(result.recognised, isFalse);
      expect(result.transactions, isEmpty);
    });
  });

  group('statement arithmetic', () {
    // Direction is derived, never read, so the statement's own totals are
    // the real check.
    for (final shape in ['pdfjs', 'pdfium']) {
      test('ActivoBank movements add up to SALDO FINAL - SALDO INICIAL ($shape)', () {
        expect(50000 + sum(parseStatementText(fixture('activobank-basic.$shape')).transactions), 100000);
      });

      test('Trade Republic in/out totals match the summary block ($shape)', () {
        final txs = parseStatementText(fixture('traderepublic-basic.$shape')).transactions;
        expect(100000 + sum(txs), 207450);
        expect(sum(txs.where((t) => t.amountCents > 0)), 115000);
        expect(sum(txs.where((t) => t.amountCents < 0)), -7550);
      });

      test('moey stops before the savings section ($shape)', () {
        final txs = parseStatementText(fixture('moey-basic.$shape')).transactions;
        expect(txs.any((t) => RegExp('renda', caseSensitive: false).hasMatch(t.payee)), isFalse);
      });

      test('the Trade Republic page footer swallows nothing ($shape)', () {
        final txs = parseStatementText(fixture('traderepublic-basic.$shape')).transactions;
        expect(txs.any((t) => t.date == '2026-08-10'), isTrue);
        expect(txs.any((t) => RegExp('berlin|traderepublic|gerado', caseSensitive: false).hasMatch(t.payee)), isFalse);
      });
    }
  });

  group('extracted text', () {
    test('CRLF line endings and page-break markers read the same as LF', () {
      final lf = fixture('moey-basic.pdfium');
      final crlf = lf.replaceAll('\n', '\r\n').replaceFirst('\r\nZZTEST001\r\n', '\r\n\f\r\nZZTEST001\r\n');
      final a = parseStatementText(lf).transactions;
      final b = parseStatementText(crlf).transactions;
      expect([for (final t in b) t.importedId], [for (final t in a) t.importedId]);
      expect(b, hasLength(7));
    });
  });

  group('warnings', () {
    test('a skipped row is reported without its amount or balance', () {
      final result = parseStatementText(fixture('activobank-unresolvable.pdfjs'));
      expect(result.transactions, hasLength(1));
      final warning = result.warnings.single;
      expect(warning.bankId, 'activobank');
      expect(warning.payee, 'LINHA CORROMPIDA');
      // Neither the amount (5.00) nor the balance (90.00) is in the warning.
      expect('${warning.message} ${warning.fields}', isNot(contains(RegExp(r'5\.00|90\.00|500|9000'))));
    });

    test('moey: a block with no amount is reported, not thrown', () {
      final result = parseStatementText('moey\n01-07-2026  /  01-07-2026COMPRA SEM VALOR');
      expect(result.transactions, isEmpty);
      expect(result.warnings.single.message, contains('no amount/balance'));
    });
  });

  group('importedId', () {
    test('repeats in one statement get distinct ids; interleaving does not renumber them', () {
      const joana = (date: '2026-07-13', amountCents: 1000, payee: 'JOANA EXEMPL');
      const other = (date: '2026-03-01', amountCents: -1234, payee: 'OTHER');
      final plain = assignImportedIds([joana, joana, joana]);
      expect(plain.toSet(), hasLength(3));
      final mixed = assignImportedIds([other, joana, other, joana, joana]);
      expect([mixed[1], mixed[3], mixed[4]], plain);
    });

    test('an id kept from earlier is used as-is and still counts as a repeat', () {
      const joana = (date: '2026-07-13', amountCents: 1000, payee: 'JOANA EXEMPL');
      final ids = assignImportedIds([joana, joana], existing: {0: 'pdfimport-from-parse'});
      expect(ids, ['pdfimport-from-parse', 'pdfimport--779377660']);
    });
  });
}
