import 'package:flutter/foundation.dart';

@immutable
class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
    required this.createdAt,
  });

  final String id;
  final String purchaseId;
  final String productId;

  final String productName;

  final int quantity;

  final double unitCost;
  final double subtotal;

  final DateTime createdAt;
}