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
  });

  final String id;
  final String saleNumber;

  final double totalAmount;
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