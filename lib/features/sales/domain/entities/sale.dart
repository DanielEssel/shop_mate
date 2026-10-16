import 'package:flutter/foundation.dart';

@immutable
class Sale {
  const Sale({
    this.customerId,
    required this.id,
    required this.saleNumber,
    required this.totalAmount,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    required this.createdAt,
    this.createdBy,
    this.discountAmount = 0,
  });

  final String id;
  final String saleNumber;

  /// The amount charged, after any discount.
  final double totalAmount;

  /// The sale's total discount, as recorded (0 for none).
  final double discountAmount;
  final String paymentMethod;

  final double amountPaid;
  final double changeAmount;

  final String? createdBy;
  final DateTime createdAt;

  final String? customerId;

  bool get isCredit => paymentMethod == 'credit';

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'mobile_money':
        return 'Mobile Money';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'credit':
        return 'Credit';
      default:
        return paymentMethod;
    }
  }
}
