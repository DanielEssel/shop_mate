
import 'package:flutter/foundation.dart';

@immutable
class DashboardRecentSale {
  const DashboardRecentSale({
    required this.id,
    required this.saleNumber,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    required this.itemCount,
  });

  final String id;
  final String saleNumber;
  final double totalAmount;
  final String paymentMethod;
  final DateTime createdAt;
  final int itemCount;

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