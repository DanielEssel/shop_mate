import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/product_categories/data/models/product_category_model.dart';

Map<String, Object?> _row() => {
  'id': 'c1',
  'shop_id': 'shop-1',
  'name': 'Beverages',
  'is_active': true,
  'created_at': '2026-10-09T09:00:00+00:00',
  'updated_at': '2026-10-09T10:00:00+00:00',
};

void main() {
  test('parses a row', () {
    final category = ProductCategoryModel.fromRow(_row());

    expect(category.id, 'c1');
    expect(category.shopId, 'shop-1');
    expect(category.name, 'Beverages');
    expect(category.isActive, isTrue);
    expect(category.updatedAt, DateTime.utc(2026, 10, 9, 10));
  });

  for (final field in _row().keys) {
    test('rejects a missing $field', () {
      expect(
        () => ProductCategoryModel.fromRow(_row()..remove(field)),
        throwsFormatException,
      );
    });
  }

  test('rejects malformed values', () {
    expect(
      () => ProductCategoryModel.fromRow({..._row(), 'is_active': 'yes'}),
      throwsFormatException,
    );
    expect(
      () => ProductCategoryModel.fromRow({..._row(), 'created_at': 'later'}),
      throwsFormatException,
    );
  });
}
