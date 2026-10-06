import '../../domain/entities/product_category.dart';

class ProductCategoryModel extends ProductCategory {
  const ProductCategoryModel({
    required super.id,
    required super.shopId,
    required super.name,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Columns read from `public.product_categories`.
  static const selectColumns =
      'id, shop_id, name, is_active, created_at, updated_at';

  factory ProductCategoryModel.fromRow(Map<String, Object?> row) {
    return ProductCategoryModel(
      id: _string(row, 'id'),
      shopId: _string(row, 'shop_id'),
      name: _string(row, 'name'),
      isActive: _bool(row, 'is_active'),
      createdAt: _timestamp(row, 'created_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid product category field: $field.');
    }
    return value;
  }

  static bool _bool(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! bool) {
      throw FormatException('Invalid product category field: $field.');
    }
    return value;
  }

  static DateTime _timestamp(Map<String, Object?> row, String field) {
    final parsed = DateTime.tryParse(_string(row, field));
    if (parsed == null) {
      throw FormatException('Invalid product category timestamp: $field.');
    }
    return parsed;
  }
}
