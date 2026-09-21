import { test } from 'node:test';
import assert from 'node:assert/strict';
import { moeyParser } from '../parsers/moey';

// Synthetic text in the shape pdf-parse extracts from a moey statement
// (invented names/amounts — never paste a real statement into a fixture).
const STATEMENT = [
  'ZZTEST001',
  'Moey é uma marca do Grupo Crédito Agrícola ',
  'CONTA MOEY / MOEY ACCOUNT',
  'DATA LANÇAMENTO / DATA VALORDESCRIÇÃOMOVIMENTOS (+/-)SALDO CONTABILÍSTICO',
  'ACCOUNT DATE / VALUE DATEDESCRIPTIONIN / OUT (+/-)ACCOUNT BALANCE',
  '01-07-2026  /  01-07-2026COMPRA MERCADO TESTE 1234567/51',
  '  2,60  -53,16',
  '02-07-2026  /  02-07-2026IPS/R0000000001-JOANA EXEMPLO',
  '  20,00 +21,50',
  '03-07-2026  /  02-07-2026OP BX VALOR 03 TRAN 1234567/16',
  '  1.017,80  --15,43',
  '04-07-2026  /  04-07-2026IPS/R0000000002-PESSOA TESTE',
  '  5,66 +-9,77',
  // Description wrapped onto a second line, amount and balance on their own lines.
  '04-07-2026  /  04-07-2026Trf imediata MARIA FICTICIA SILVA',
  'SANTOS',
  '  ',
  '130,00',
  '  -35,00',
  // Page break in the middle of a movement.
  '05-07-2026  /  05-07-2026Trf imediata ANTONIO INVENTADO',
  '',
  'ZZTEST001',
  'Nome / Name',
  'CLIENTE DE TESTE',
  'Extracto em EUR',
  'CONTA MOEY / MOEY ACCOUNT',
  'DATA LANÇAMENTO / DATA VALORDESCRIÇÃOMOVIMENTOS (+/-)SALDO CONTABILÍSTICO',
  'ACCOUNT DATE / VALUE DATEDESCRIPTIONIN / OUT (+/-)ACCOUNT BALANCE',
  'COSTA',
  '  ',
  '12,00',
  '  -66,45',
  // Amount and balance on the same line.
  '06-07-2026  /  06-07-2026Trf imediata OUTRA PESSOA',
  '10,00  -92,92',
  'SALDO FINAL208,01',
  'FINAL BALANCE',
  // Savings section: mirrors transfers already listed above, must be ignored.
  'CONTA POUPANÇA / SAVINGS',
  '03-07-2026  /  03-07-2026TRSF.P/RENDA  10,00',
  ' +165,00',
].join('\n');

test('canParse recognises a moey statement', () => {
  assert.equal(moeyParser.canParse(STATEMENT), true);
  assert.equal(moeyParser.canParse('ActivoBank extracto'), false);
});

test('parse reads date, cleaned payee and signed amount from each movement', async () => {
  const txs = await moeyParser.parse(STATEMENT);
  assert.deepEqual(
    txs.map(({ date, payee, amountCents }) => ({ date, payee, amountCents })),
    [
      { date: '2026-07-01', payee: 'MERCADO TESTE', amountCents: -260 },
      { date: '2026-07-02', payee: 'JOANA EXEMPLO', amountCents: 2000 },
      { date: '2026-07-03', payee: 'OP BX VALOR 03 TRAN', amountCents: -101780 },
      { date: '2026-07-04', payee: 'PESSOA TESTE', amountCents: 566 },
      { date: '2026-07-04', payee: 'MARIA FICTICIA SILVA SANTOS', amountCents: -13000 },
      { date: '2026-07-05', payee: 'ANTONIO INVENTADO COSTA', amountCents: -1200 },
      { date: '2026-07-06', payee: 'OUTRA PESSOA', amountCents: -1000 },
    ],
  );
});

test('parse stops at the savings-account section', async () => {
  const txs = await moeyParser.parse(STATEMENT);
  assert.equal(txs.some((t) => /renda/i.test(t.payee)), false);
});

test('a description line shaped like a page code does not swallow later movements', async () => {
  // HEADER_START_RE (/^[A-Z]{3,}\d{2,}\w*$/) sniffs the repeated page-code
  // line, but a wrapped description can have that exact shape — the real
  // statements contain payees like "MBWAY IFTHEN". Before the date-line
  // guard this dropped every movement after it, warning only about the
  // first, so a statement silently imported short.
  const txs = await moeyParser.parse(
    [
      'moey',
      '01-07-2026  /  01-07-2026Trf imediata LOJA GRANDE',
      'IFTHEN25', // looks like a page code, is really a wrapped payee
      '  10,00  -10,00',
      '02-07-2026  /  02-07-2026COMPRA MERCADO A 1234567/51',
      '  5,00  -15,00',
      '03-07-2026  /  03-07-2026COMPRA MERCADO B 1234567/52',
      '  7,00  -22,00',
    ].join('\n'),
  );

  // The tripped block itself is still lost (and logged), but the movements
  // after it must survive.
  assert.deepEqual(
    txs.map(({ date, amountCents }) => ({ date, amountCents })),
    [
      { date: '2026-07-02', amountCents: -500 },
      { date: '2026-07-03', amountCents: -700 },
    ],
  );
});
