import 'package:flutter/foundation.dart';

/// A product category owned by one shop. Archived categories
/// ([isActive] false) keep their products but are not offered for new ones.
@immutable
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.shopId,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
