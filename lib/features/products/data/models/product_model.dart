import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.sellingPrice,
    required super.costPrice,
    required super.stockQuantity,
    required super.lowStockThreshold,
    super.categoryId,
    super.categoryName,
    super.categoryIsActive,
    super.sku,
    super.barcode,
    super.description,
    super.isActive,
    super.createdAt,
    super.updatedAt,
    super.imageUrl,
  });

  /// Columns read for products: every product column plus its category's
  /// name and status through the `category_id` relationship.
  static const selectColumns = '*, product_categories(name, is_active)';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = _CategoryFields.from(
      json['category_id'],
      json['product_categories'],
      json['category'],
    );

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: category.id,
      categoryName: category.name,
      categoryIsActive: category.isActive,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      description: json['description'] as String?,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 10,

      imageUrl: json['image_url'] as String?,

      // Fix bool?
      isActive: json['is_active'] as bool? ?? true,

      // Fix String? → DateTime?
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,

      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'stock_quantity': stockQuantity,
      'low_stock_threshold': lowStockThreshold,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'image_url': imageUrl,
    };
  }
}

/// Category fields of a product row, parsed strictly.
class _CategoryFields {
  const _CategoryFields(this.id, this.name, this.isActive);

  /// [categoryId] is `category_id`; [embedded] is the joined
  /// `product_categories` row; [legacyText] is the `category` text mirror,
  /// used only for text written by older app versions that is not linked
  /// to a category.
  factory _CategoryFields.from(
    Object? categoryId,
    Object? embedded,
    Object? legacyText,
  ) {
    if (categoryId != null && categoryId is! String) {
      throw const FormatException('Invalid product field: category_id.');
    }

    if (embedded is Map) {
      final name = embedded['name'];
      final isActive = embedded['is_active'];
      if (name is! String || isActive is! bool) {
        throw const FormatException('Invalid product category.');
      }
      return _CategoryFields(categoryId as String?, name, isActive);
    }

    final text = legacyText is String ? legacyText.trim() : '';
    return _CategoryFields(
      categoryId as String?,
      text.isEmpty ? null : text,
      true,
    );
  }

  final String? id;
  final String? name;
  final bool isActive;
}
