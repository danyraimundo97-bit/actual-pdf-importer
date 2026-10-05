import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tradeRepublicParser } from '../parsers/traderepublic';

const NB = ' '; // pdf-parse returns NBSP for Trade Republic's thousands/currency gaps

// Synthetic text in the shape pdf-parse extracts from a Trade Republic
// statement (invented names/amounts — never paste a real statement into a
// fixture). Reproduces the quirks that matter: a date split over two lines,
// a wrapped type, no sign anywhere (ENTRADA/SAÍDA are columns the text dump
// flattens), the amount glued to the end of the description, and a page
// footer landing mid-table.
//
// Balances: 1000.00 +5.00 -10.00 +1145.00 -65.50 = 2074.50
const STATEMENT = [
  'TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-2110119 BERLIN',
  'DATA',
  '01 ago. 2026 - 31 ago. 2026',
  'Trade Republic Bank GmbH',
  'RESUMO DO EXTRATO DE CONTA',
  `PRODUTOSALDO INICIALENTRADA DE DINHEIROSAÍDA DE DINHEIROSALDO FINAL`,
  `Conta de valores1${NB}000,00${NB}€1${NB}150,00${NB}€75,50${NB}€2${NB}074,50${NB}€`,
  'TRANSAÇÕES',
  'DATATIPODESCRIÇÃO',
  'ENTRADA DE ',
  'DINHEIRO',
  'SAÍDA DE ',
  'DINHEIRO',
  'SALDO',
  '01 ago. ',
  '2026',
  'Juros',
  `Interest payment5,00${NB}€1${NB}005,00${NB}€`,
  // The bank truncates descriptions to a fixed width, so one can end in a
  // digit: "LOJA TESTE 410,00" is the payee "LOJA TESTE 4" and 10,00, which
  // only the balance delta can disentangle.
  '03 ago. ',
  '2026',
  'Transação com ',
  'cartão',
  `LOJA TESTE 410,00${NB}€995,00${NB}€`,
  // Long description wraps, pushing amount and balance onto their own line.
  '05 ago. ',
  '2026',
  'Transferência',
  'Incoming transfer from PESSOA TESTE ',
  '(PT50000000000000000000000)',
  `1${NB}145,00${NB}€2${NB}140,00${NB}€`,
  // Page break: address footer plus repeated column headers, mid-table.
  '',
  'TRADE REPUBLIC BANK GMBH  BRUNNENSTRASSE 19-2110119 BERLIN',
  'Trade Republic Bank GmbH',
  'Brunnenstraße 19-21',
  '10119 Berlin',
  'www.traderepublic.comSede da empresa: Berlin',
  'Gerado no dia 2026-09-01 00:00:00 Europe/Lisbon (UTC+01:00)Página   2de2',
  'DATATIPODESCRIÇÃO',
  'ENTRADA DE ',
  'DINHEIRO',
  'SAÍDA DE ',
  'DINHEIRO',
  'SALDO',
  '10 ago. ',
  '2026',
  'Transação com ',
  'cartão',
  `MERCADO TESTE65,50${NB}€2${NB}074,50${NB}€`,
  'SÍNTESE DO BALANÇO',
  'em 31 ago. 2026',
  'CONTAS COLETIVASSALDO',
  `Deutsche Bank2${NB}074,50${NB}€`,
].join('\n');

test('canParse recognises a Trade Republic statement', () => {
  assert.equal(tradeRepublicParser.canParse(STATEMENT), true);
  assert.equal(tradeRepublicParser.canParse('Banco ActivoBank, S.A.'), false);
});

test('canParse ignores another bank listing Trade Republic as a payee', () => {
  // A moey statement truncates the payee column, so it contains
  // "TRANSF SEPA -Trade Republic Ba". The old /trade\s*republic/i sniff
  // matched that and claimed the whole moey statement; it only routed
  // correctly because moey happens to come first in REGEX_PARSERS.
  assert.equal(
    tradeRepublicParser.canParse('07-07-2026 TRANSF SEPA -Trade Republic Ba 100,00 +102,90'),
    false,
  );
});

test('parse reads date, cleaned payee and signed amount from each movement', async () => {
  const txs = await tradeRepublicParser.parse(STATEMENT);
  assert.deepEqual(
    txs.map(({ date, payee, amountCents }) => ({ date, payee, amountCents })),
    [
      { date: '2026-08-01', payee: 'Interest payment', amountCents: 500 },
      { date: '2026-08-03', payee: 'LOJA TESTE 4', amountCents: -1000 },
      { date: '2026-08-05', payee: 'PESSOA TESTE', amountCents: 114500 },
      { date: '2026-08-10', payee: 'MERCADO TESTE', amountCents: -6550 },
    ],
  );
});

test('the movement total matches the summary block', async () => {
  // Direction is derived, never read, so the statement's own totals are the
  // only meaningful check: SALDO INICIAL + sum == SALDO FINAL, and the
  // in/out split matches ENTRADA/SAÍDA DE DINHEIRO.
  const txs = await tradeRepublicParser.parse(STATEMENT);
  const sum = txs.reduce((total, tx) => total + tx.amountCents, 0);
  const inflow = txs.filter((t) => t.amountCents > 0).reduce((a, t) => a + t.amountCents, 0);
  const outflow = txs.filter((t) => t.amountCents < 0).reduce((a, t) => a + t.amountCents, 0);

  assert.equal(100000 + sum, 207450);
  assert.equal(inflow, 115000);
  assert.equal(outflow, -7550);
});

test('the page footer does not swallow the movements after it', async () => {
  const txs = await tradeRepublicParser.parse(STATEMENT);
  assert.equal(txs.some((t) => t.date === '2026-08-10'), true);
  assert.equal(txs.some((t) => /berlin|traderepublic|gerado/i.test(t.payee)), false);
});

test('without SALDO INICIAL only the first movement is lost', async () => {
  // The opening balance is the anchor for the first delta. Every later row
  // can still be derived from the balance it prints, so a missing summary
  // block costs one movement rather than the whole statement.
  const txs = await tradeRepublicParser.parse(
    [
      'Trade Republic Bank GmbH',
      'TRANSAÇÕES',
      '01 ago. ',
      '2026',
      'Transação com ',
      'cartão',
      `LOJA PRIMEIRA10,00${NB}€990,00${NB}€`,
      '02 ago. ',
      '2026',
      'Transação com ',
      'cartão',
      `LOJA SEGUNDA40,00${NB}€950,00${NB}€`,
      'SÍNTESE DO BALANÇO',
    ].join('\n'),
  );
  assert.deepEqual(
    txs.map(({ payee, amountCents }) => ({ payee, amountCents })),
    [{ payee: 'LOJA SEGUNDA', amountCents: -4000 }],
  );
});
