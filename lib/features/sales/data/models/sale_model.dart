import '../../domain/entities/sale.dart';

class SaleModel extends Sale {
  const SaleModel({
    required super.id,
    required super.saleNumber,
    required super.totalAmount,
    required super.paymentMethod,
    required super.amountPaid,
    required super.changeAmount,
    required super.createdAt,
    super.createdBy,
    super.customerId,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] as String,
      saleNumber: json['sale_number'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      changeAmount: (json['change_amount'] as num).toDouble(),
      createdBy: json['created_by'] as String?,
      customerId: json['customer_id'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_number': saleNumber,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'created_by': createdBy,
      'customer_id': customerId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
