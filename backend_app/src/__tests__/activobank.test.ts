import { test } from 'node:test';
import assert from 'node:assert/strict';
import { activoBankParser } from '../parsers/activobank';

// Synthetic text in the shape pdf-parse extracts from an ActivoBank
// statement (invented names/amounts — never paste a real statement into a
// fixture). Reproduces the quirks that matter: a three-line movement, a
// date line with no year, "." decimals with SPACE thousands, and the amount
// glued to the running balance with no sign anywhere.
//
// Balances: 500.00 -25.50 -10.00 -64.50 +1200.00 -100.00 -500.00 = 1000.00
const STATEMENT = [
  'Banco ActivoBank, S.A. - Sede: Rua Augusta, 84, 1100-053 Lisboa',
  'CONTA SIMPLES',
  'N. ',
  '00000000000',
  'MOEDA:   EUR',
  'EXTRATO DE',
  ' 2026/07/01 A 2026/07/31',
  'DATA',
  'LANC.',
  'DATA',
  'VALOR',
  'DESCRITIVODEBITOCREDITOSALDO',
  'SALDO INICIAL',
  '500.00            ',
  '7.01  7.01',
  'COMPRA 1234 LOJA TESTE',
  '25.50474.50',
  '7.03  7.03',
  'TRF MB WAY P/ PESSOA TESTE',
  '10.00464.50',
  '7.05  7.05',
  'DD EMPRESA TESTE        12345678901    PT99999999',
  '64.50400.00',
  // Credit, and a thousands separator in both the amount and the balance.
  '7.10  7.10',
  'TRANSFERENCIA - SALARIO',
  '1 200.001 600.00',
  // Description wrapped onto a second line.
  '7.15  7.15',
  'COMPRA MERCADO MUITO',
  'GRANDE LDA',
  '100.001 500.00',
  '7.20  7.20',
  'TRF P/ OUTRA PESSOA',
  '500.001 000.00',
  'SALDO FINAL',
  '1 000.00',
  'SALDO DISPONIVEL',
  '1 000.00',
].join('\n');

test('canParse recognises an ActivoBank statement', () => {
  assert.equal(activoBankParser.canParse(STATEMENT), true);
  assert.equal(activoBankParser.canParse('moey é uma marca do Grupo Crédito Agrícola'), false);
});

test('canParse ignores a statement that merely mentions ActivoBank', () => {
  // Another bank's statement listing an ActivoBank transfer as the payee.
  // The old substring sniff claimed it, and because activobank is first in
  // REGEX_PARSERS that hijacked the statement from its real parser.
  assert.equal(
    activoBankParser.canParse('01-07-2026 Trf imediata ACTIVOBANK 10,00 -10,00'),
    false,
  );
});

test('parse reads date, cleaned payee and signed amount from each movement', async () => {
  const txs = await activoBankParser.parse(STATEMENT);
  assert.deepEqual(
    txs.map(({ date, payee, amountCents }) => ({ date, payee, amountCents })),
    [
      { date: '2026-07-01', payee: 'LOJA TESTE', amountCents: -2550 },
      { date: '2026-07-03', payee: 'PESSOA TESTE', amountCents: -1000 },
      { date: '2026-07-05', payee: 'EMPRESA TESTE', amountCents: -6450 },
      { date: '2026-07-10', payee: 'SALARIO', amountCents: 120000 },
      { date: '2026-07-15', payee: 'MERCADO MUITO GRANDE LDA', amountCents: -10000 },
      { date: '2026-07-20', payee: 'OUTRA PESSOA', amountCents: -50000 },
    ],
  );
});

test('the movement total matches SALDO FINAL minus SALDO INICIAL', async () => {
  // The statement's own arithmetic is the only real check on a layout where
  // direction is recovered rather than read.
  const txs = await activoBankParser.parse(STATEMENT);
  const sum = txs.reduce((total, tx) => total + tx.amountCents, 0);
  assert.equal(50000 + sum, 100000);
});

test('the year comes from the period header, and rolls over mid-statement', async () => {
  // Date lines are MONTH.DAY with no year at all. A month before the
  // period's first month belongs to the next calendar year.
  const txs = await activoBankParser.parse(
    [
      'Banco ActivoBank, S.A.',
      'EXTRATO DE',
      ' 2026/12/01 A 2027/01/31',
      'SALDO INICIAL',
      '100.00',
      '12.28  12.28',
      'COMPRA LOJA DEZEMBRO',
      '10.0090.00',
      '1.04  1.04',
      'COMPRA LOJA JANEIRO',
      '20.0070.00',
      'SALDO FINAL',
      '70.00',
    ].join('\n'),
  );
  assert.deepEqual(
    txs.map(({ date, amountCents }) => ({ date, amountCents })),
    [
      { date: '2026-12-28', amountCents: -1000 },
      { date: '2027-01-04', amountCents: -2000 },
    ],
  );
});

test('a movement whose amount cannot be resolved is skipped, not fatal', async () => {
  // "5.0090.00" splits cleanly into two amounts but neither direction
  // reconciles against the previous balance (100.00 -/+ 5.00 is 95/105, not
  // 90). The row is dropped and the balance resyncs so later rows survive.
  const txs = await activoBankParser.parse(
    [
      'Banco ActivoBank, S.A.',
      'EXTRATO DE',
      ' 2026/07/01 A 2026/07/31',
      'SALDO INICIAL',
      '100.00',
      '7.01  7.01',
      'COMPRA LINHA CORROMPIDA',
      '5.0090.00',
      '7.02  7.02',
      'COMPRA LOJA SEGUINTE',
      '10.0080.00',
      'SALDO FINAL',
      '80.00',
    ].join('\n'),
  );
  assert.deepEqual(
    txs.map(({ payee, amountCents }) => ({ payee, amountCents })),
    [{ payee: 'LOJA SEGUINTE', amountCents: -1000 }],
  );
});

test('a statement with no period header yields nothing rather than a guessed year', async () => {
  const txs = await activoBankParser.parse(
    ['Banco ActivoBank, S.A.', 'SALDO INICIAL', '100.00', '7.01  7.01', 'COMPRA X', '10.0090.00', 'SALDO FINAL', '90.00'].join('\n'),
  );
  assert.deepEqual(txs, []);
});
