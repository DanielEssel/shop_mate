import 'package:flutter/foundation.dart';

import '../../../products/domain/entities/product.dart';

@immutable
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  double get subtotal {
    return product.sellingPrice * quantity;
  }

  double get profit {
    return product.profitPerUnit * quantity;
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}