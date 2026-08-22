import 'package:flutter/foundation.dart';

@immutable
class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.subtotal,
    required this.createdAt,
  });

  final String id;
  final String saleId;
  final String productId;
  final String productName;

  final int quantity;

  final double unitPrice;
  final double costPrice;
  final double subtotal;

  final DateTime createdAt;

  double get profit {
    return (unitPrice - costPrice) * quantity;
  }
}