import '../../domain/entities/sale_payment_summary.dart';

class SalePaymentSummaryModel extends SalePaymentSummary {
  const SalePaymentSummaryModel({
    required super.paidAmount,
    required super.paymentMethods,
  });

  factory SalePaymentSummaryModel.fromAllocations(
    Iterable<Map<String, dynamic>> allocations,
  ) {
    var paidAmount = 0.0;
    final paymentMethods = <String>{};

    for (final allocation in allocations) {
      final amount = allocation['amount'];
      final payment = allocation['customer_payments'];

      if (amount is! num || payment is! Map<String, dynamic>) {
        throw const FormatException('Invalid sale payment allocation.');
      }

      final paymentMethod = payment['payment_method'];

      if (paymentMethod is! String) {
        throw const FormatException('Invalid sale payment method.');
      }

      paidAmount += amount.toDouble();
      paymentMethods.add(paymentMethod);
    }

    return SalePaymentSummaryModel(
      paidAmount: paidAmount,
      paymentMethods: List.unmodifiable(paymentMethods),
    );
  }
}
