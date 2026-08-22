import 'package:flutter/foundation.dart';

import '../../../products/domain/entities/product.dart';

@immutable
class PurchaseCartItem {
  const PurchaseCartItem({
    required this.product,
    required this.quantity,
    required this.unitCost,
  });

  final Product product;
  final int quantity;
  final double unitCost;

  double get subtotal {
    return unitCost * quantity;
  }

  PurchaseCartItem copyWith({
    Product? product,
    int? quantity,
    double? unitCost,
  }) {
    return PurchaseCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}