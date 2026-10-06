import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/products/data/models/product_model.dart';

Map<String, dynamic> _row({
  Object? categoryId,
  Object? embedded,
  String category = '',
}) {
  return {
    'id': 'p1',
    'name': 'Milk',
    'category': category,
    'category_id': categoryId,
    'product_categories': embedded,
    'cost_price': 2,
    'selling_price': 3,
    'stock_quantity': 5,
    'low_stock_threshold': 1,
    'is_active': true,
  };
}

void main() {
  test('a linked category comes from the joined row', () {
    final product = ProductModel.fromJson(
      _row(
        categoryId: 'c1',
        embedded: {'name': 'Dairy', 'is_active': true},
        category: 'Dairy',
      ),
    );

    expect(product.categoryId, 'c1');
    expect(product.categoryName, 'Dairy');
    expect(product.categoryIsActive, isTrue);
  });

  test('an archived category is still shown and flagged', () {
    final product = ProductModel.fromJson(
      _row(categoryId: 'c1', embedded: {'name': 'Dairy', 'is_active': false}),
    );

    expect(product.categoryName, 'Dairy');
    expect(product.categoryIsActive, isFalse);
  });

  test('no category: null id and name', () {
    final product = ProductModel.fromJson(_row());

    expect(product.categoryId, isNull);
    expect(product.categoryName, isNull);
  });

  test('legacy unlinked text from older app versions is still shown', () {
    final product = ProductModel.fromJson(_row(category: ' Personal Care '));

    expect(product.categoryId, isNull);
    expect(product.categoryName, 'Personal Care');
  });

  test('a row without the new columns (older reads) still parses', () {
    final row = _row(category: 'Dairy')
      ..remove('category_id')
      ..remove('product_categories');

    final product = ProductModel.fromJson(row);

    expect(product.categoryId, isNull);
    expect(product.categoryName, 'Dairy');
  });

  test('malformed category data is rejected', () {
    expect(
      () => ProductModel.fromJson(_row(categoryId: 42)),
      throwsFormatException,
    );
    expect(
      () => ProductModel.fromJson(
        _row(categoryId: 'c1', embedded: {'name': 7, 'is_active': true}),
      ),
      throwsFormatException,
    );
  });

  test('toJson writes category_id, never the legacy text', () {
    final json = ProductModel.fromJson(
      _row(categoryId: 'c1', embedded: {'name': 'Dairy', 'is_active': true}),
    ).toJson();

    expect(json['category_id'], 'c1');
    expect(json.containsKey('category'), isFalse);
  });
}
