import 'package:flutter/foundation.dart';

import 'product_category.dart';

/// A category with the number of active products assigned to it.
@immutable
class ProductCategorySummary {
  const ProductCategorySummary({
    required this.category,
    required this.activeProductCount,
  });

  final ProductCategory category;
  final int activeProductCount;
}
