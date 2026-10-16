import '../../domain/entities/sale_item.dart';

class SaleItemModel extends SaleItem {
  const SaleItemModel({
    required super.id,
    required super.saleId,
    required super.productId,
    required super.productName,
    required super.quantity,
    required super.unitPrice,
    required super.costPrice,
    required super.subtotal,
    required super.createdAt,
    super.originalUnitPrice,
    super.discountPercentage,
    super.discountAmount,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      // Discount snapshots; absent on data from before discounts existed.
      originalUnitPrice: (json['original_unit_price'] as num?)?.toDouble(),
      discountPercentage:
          (json['discount_percentage'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'subtotal': subtotal,
      'original_unit_price': originalUnitPrice,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
