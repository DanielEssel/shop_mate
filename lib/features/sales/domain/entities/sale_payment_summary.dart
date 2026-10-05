import 'package:flutter/foundation.dart';

@immutable
class SalePaymentSummary {
  const SalePaymentSummary({
    required this.paidAmount,
    required this.paymentMethods,
  });

  final double paidAmount;
  final List<String> paymentMethods;
}
