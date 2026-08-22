import '../../domain/entities/purchase.dart';

class PurchaseModel extends Purchase {
  const PurchaseModel({
    required super.id,
    required super.purchaseNumber,
    required super.totalAmount,
    required super.amountPaid,
    required super.balance,
    required super.paymentMethod,
    required super.status,
    required super.purchaseDate,
    required super.createdAt,
    required super.updatedAt,
    super.supplierName,
    super.supplierPhone,
    super.notes,
    super.createdBy,
  });

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    return PurchaseModel(
      id: json['id'] as String,
      purchaseNumber: json['purchase_number'] as String,
      supplierName: json['supplier_name'] as String?,
      supplierPhone: json['supplier_phone'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      amountPaid: (json['amount_paid'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      purchaseDate: DateTime.parse(
        json['purchase_date'].toString(),
      ),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(
        json['created_at'].toString(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'].toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_number': purchaseNumber,
      'supplier_name': supplierName,
      'supplier_phone': supplierPhone,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'balance': balance,
      'payment_method': paymentMethod,
      'status': status,
      'purchase_date': purchaseDate.toIso8601String().split('T').first,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}