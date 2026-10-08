import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/product.dart';

/// The one mapping from a product's stock to its status label and tone.
({String label, StatusTone tone}) stockStatusOf(Product product) {
  if (product.isOutOfStock) {
    return (label: 'Out of stock', tone: StatusTone.danger);
  }
  if (product.isLowStock) {
    return (label: 'Low stock', tone: StatusTone.warning);
  }
  return (label: 'In stock', tone: StatusTone.success);
}

/// e.g. "24 in stock", "3 left", "None left".
String stockQuantityLabel(Product product) {
  if (product.isOutOfStock) return 'None left';
  if (product.isLowStock) return '${product.stockQuantity} left';
  return '${product.stockQuantity} in stock';
}

/// The product's stock status as a badge.
class ProductStockBadge extends StatelessWidget {
  const ProductStockBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(product);
    return StatusBadge(label: status.label, tone: status.tone);
  }
}

/// The product's photo, or its initial while there is none (or it fails).
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.product, this.size = 36});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl?.trim();
    final fallback = InitialAvatar(name: product.name, size: size);

    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceMuted,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
