import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/product_categories/domain/entities/product_category_exception.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_name.dart';

void main() {
  test('trims surrounding whitespace', () {
    expect(ProductCategoryName('  Drinks ').value, 'Drinks');
  });

  test('keeps case and inner spacing', () {
    expect(ProductCategoryName("Men's  Perfume").value, "Men's  Perfume");
  });

  test('accepts 1 and 60 characters', () {
    expect(ProductCategoryName('A').value, 'A');
    expect(ProductCategoryName('n' * 60).value.length, 60);
  });

  for (final input in ['', '    ', 'n' * 61]) {
    test(
      'rejects "${input.length > 10 ? '${input.length} chars' : input}"',
      () {
        expect(
          () => ProductCategoryName(input),
          throwsA(
            isA<ProductCategoryException>().having(
              (e) => e.kind,
              'kind',
              ProductCategoryErrorKind.invalidName,
            ),
          ),
        );
      },
    );
  }

  test('isValid mirrors the factory', () {
    expect(ProductCategoryName.isValid(' Drinks '), isTrue);
    expect(ProductCategoryName.isValid('   '), isFalse);
    expect(ProductCategoryName.isValid('n' * 61), isFalse);
  });

  test('every error kind has a user-safe message', () {
    for (final kind in ProductCategoryErrorKind.values) {
      expect(kind.message, isNotEmpty);
    }
  });
}
