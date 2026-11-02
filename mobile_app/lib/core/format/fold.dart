/// Removes Portuguese/Spanish/French accents ("Farmácia" → "Farmacia"),
/// both cases. Dart has no Unicode normalisation built in, and these are
/// the letters bank statements and category names use.
String foldAccents(String s) {
  final out = StringBuffer();
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    out.write(_accents[c] ?? c);
  }
  return out.toString();
}

const _accents = {
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'Ç': 'C', 'ç': 'c', 'Ñ': 'N', 'ñ': 'n',
};
