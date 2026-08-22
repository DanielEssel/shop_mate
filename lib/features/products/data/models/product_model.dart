import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.category,
    required super.sellingPrice,
    required super.costPrice,
    required super.stockQuantity,
    required super.lowStockThreshold,
    super.sku,
    super.barcode,
    super.description,
    super.isActive,
    super.createdAt,
    super.updatedAt,
    super.imageUrl,
  });

  factory ProductModel.fromJson(
  Map<String, dynamic> json,
) {
  return ProductModel(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    sku: json['sku'] as String?,
    barcode: json['barcode'] as String?,
    description: json['description'] as String?,
    costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
    sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
    stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
    lowStockThreshold:
        (json['low_stock_threshold'] as num?)?.toInt() ?? 10,

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
      'category': category,
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