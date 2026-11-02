import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/category_suggestions.dart';
import 'package:mobile_app/data/models/category_mapping.dart';
import 'package:mobile_app/data/models/parsed_transaction.dart';

ParsedTransaction tx(String payee, {String? suggested}) => ParsedTransaction(
  date: DateTime(2026, 7, 1),
  payee: payee,
  amountCents: -100,
  rawLine: '',
  importedId: 'pdfimport-1',
  suggestedCategoryId: suggested,
);

CategoryMapping mapping(String payee, String id) =>
    CategoryMapping(payee: payee, categoryId: id, categoryName: 'Name $id', updatedAt: '');

void main() {
  test('the key matches the backend: trimmed, lower case, single spaces', () {
    expect(categoryMemoryKey('  Café   Central\t LDA '), 'café central lda');
  });

  test("the budget's mapping wins over an unscoped one", () {
    final out = applyCategoryMemory(
      [tx('SHOP'), tx('Bakery'), tx('Unknown')],
      scoped: [mapping('shop', 'budget')],
      unscoped: [mapping('SHOP', 'old'), mapping('bakery', 'old-bakery')],
    );
    expect(out.map((t) => t.suggestedCategoryId), ['budget', 'old-bakery', null]);
    expect(out.first.suggestedCategoryName, 'Name budget');
  });

  test('an existing suggestion is kept', () {
    final out = applyCategoryMemory([tx('SHOP', suggested: 'mine')], scoped: [mapping('shop', 'memory')]);
    expect(out.single.suggestedCategoryId, 'mine');
  });
}
