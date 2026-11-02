/// Starter hints for Portuguese merchants (docs/plans/dart-parser.md,
/// Phase 4): the lowest-priority suggestion, after the user's own memory.
/// Shown with a "hint" badge; accepting one records a real mapping.
library;

/// Merchant names (whole words) → a preset category key. Checked in
/// order, so a more specific name goes before a shorter one that it
/// contains (GALP ENERGIA before GALP).
const _hints = <(List<String>, String)>[
  (['GALP ENERGIA', 'EDP', 'EPAL', 'ENDESA', 'GOLDENERGY'], 'home.utilities'),
  (['CONTINENTE', 'PINGO DOCE', 'LIDL', 'ALDI', 'MERCADONA', 'INTERMARCHE', 'MINIPRECO'], 'food.groceries'),
  (['GALP', 'REPSOL', 'BP', 'PRIO', 'CEPSA'], 'transport.fuel'),
  (['UBER', 'BOLT', 'FREE NOW'], 'transport.taxi'),
  (['VIA VERDE'], 'transport.car'),
  (['NETFLIX', 'SPOTIFY', 'DISNEY', 'HBO'], 'personal.subscriptions'),
  (['FARMACIA'], 'health.pharmacy'),
  (['MEO', 'NOS', 'VODAFONE', 'DIGI'], 'home.internet'),
  (['COMISSAO', 'IMPOSTO DO SELO'], 'money.fees'),
];

final _patterns = [
  for (final (names, key) in _hints)
    (RegExp('\\b(?:${names.map((n) => RegExp.escape(n).replaceAll(' ', r'\s+')).join('|')})\\b'), key),
];

/// The preset key a payee hints at, or null. Case- and accent-insensitive
/// ("Farmácia" matches FARMACIA).
String? hintPresetKey(String payee) {
  final text = _foldAccents(payee.toUpperCase());
  for (final (pattern, key) in _patterns) {
    if (pattern.hasMatch(text)) return key;
  }
  return null;
}

const _accents = {
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', //
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', //
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', //
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', //
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', //
  'Ç': 'C', 'Ñ': 'N',
};

String _foldAccents(String s) => s.split('').map((c) => _accents[c] ?? c).join();
