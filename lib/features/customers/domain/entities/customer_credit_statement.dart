import 'package:flutter/foundation.dart';

@immutable
class CustomerCreditStatement {
  const CustomerCreditStatement({
    required this.totalCreditSales,
    required this.totalPaid,
    required this.outstandingBalance,
    required this.outstandingSaleCount,
    required this.outstandingSales,
    required this.paymentHistory,
  });

  final double totalCreditSales;
  final double totalPaid;
  final double outstandingBalance;
  final int outstandingSaleCount;
  final List<OutstandingCreditSale> outstandingSales;
  final List<CustomerPaymentHistoryEntry> paymentHistory;
}

@immutable
class OutstandingCreditSale {
  const OutstandingCreditSale({
    required this.id,
    required this.saleNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
  });

  final String id;
  final String saleNumber;
  final DateTime createdAt;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
}

@immutable
class CustomerPaymentHistoryEntry {
  const CustomerPaymentHistoryEntry({
    required this.id,
    required this.paidAt,
    required this.amount,
    required this.paymentMethod,
    required this.allocatedSaleNumbers,
    this.reference,
    this.note,
  });

  final String id;
  final DateTime paidAt;
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? note;
  final List<String> allocatedSaleNumbers;
}
