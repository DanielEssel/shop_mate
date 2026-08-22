import 'package:flutter/foundation.dart';

@immutable
class Purchase {
  const Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    required this.paymentMethod,
    required this.status,
    required this.purchaseDate,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.supplierPhone,
    this.notes,
    this.createdBy,
  });

  final String id;
  final String purchaseNumber;

  final String? supplierName;
  final String? supplierPhone;

  final double totalAmount;
  final double amountPaid;
  final double balance;

  final String paymentMethod;
  final String status;

  final DateTime purchaseDate;

  final String? notes;
  final String? createdBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFullyPaid => balance <= 0;

  bool get hasBalance => balance > 0;
}