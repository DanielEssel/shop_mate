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
    this.originalUnitPrice,
    this.discountPercentage = 0,
    this.discountAmount = 0,
  });

  final String id;
  final String saleId;
  final String productId;
  final String productName;

  final int quantity;

  /// The final price charged per unit (after any discount).
  final double unitPrice;
  final double costPrice;

  /// The final line total, as recorded.
  final double subtotal;

  /// The product's selling price when sold, before any discount (null on
  /// rows recorded before discounts existed: same as [unitPrice]).
  final double? originalUnitPrice;

  /// The discount percentage this line actually got (0 for none).
  final double discountPercentage;

  /// The line's total discount, as recorded.
  final double discountAmount;

  final DateTime createdAt;

  /// The price per unit before any discount.
  double get listUnitPrice => originalUnitPrice ?? unitPrice;

  /// Whether this line actually got money off (a running discount alone
  /// doesn't count: cost-protected lines record none).
  bool get isDiscounted => discountAmount > 0;

  double get profit {
    return (unitPrice - costPrice) * quantity;
  }
}
