import 'package:flutter/foundation.dart';

@immutable
class CustomerPaymentAllocation {
  const CustomerPaymentAllocation({required this.saleId, required this.amount});

  final String saleId;
  final double amount;
}

@immutable
class RecordCustomerPaymentRequest {
  const RecordCustomerPaymentRequest({
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    required this.idempotencyKey,
    required this.allocations,
    this.reference,
    this.note,
  });

  final String customerId;
  final double amount;
  final String paymentMethod;
  final DateTime paidAt;
  final String idempotencyKey;
  final List<CustomerPaymentAllocation> allocations;
  final String? reference;
  final String? note;
}
