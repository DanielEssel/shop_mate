import 'package:flutter/foundation.dart';

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    this.categoryId,
    this.categoryName,
    this.categoryIsActive = true,
    this.sku,
    this.barcode,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
  });

  final String id;
  final String name;

  /// Optional category of the product's shop; null for no category.
  final String? categoryId;

  /// Display name of the category, or null when the product has none.
  final String? categoryName;

  /// False when the product's category has since been archived.
  final bool categoryIsActive;

  final String? sku;
  final String? barcode;
  final String? description;

  final double costPrice;
  final double sellingPrice;

  final int stockQuantity;
  final int lowStockThreshold;

  final bool isActive;
  final String? imageUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get profitPerUnit {
    return sellingPrice - costPrice;
  }

  double get profitMargin {
    if (sellingPrice <= 0) {
      return 0;
    }

    return (profitPerUnit / sellingPrice) * 100;
  }

  bool get isLowStock {
    return stockQuantity > 0 && stockQuantity <= lowStockThreshold;
  }

  bool get isOutOfStock {
    return stockQuantity <= 0;
  }
}
