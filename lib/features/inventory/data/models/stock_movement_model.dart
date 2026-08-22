import '../../domain/entities/stock_movement.dart';

class StockMovementModel extends StockMovement {
  const StockMovementModel({
    required super.id,
    required super.productId,
    required super.movementType,
    required super.quantity,
    required super.previousQuantity,
    required super.newQuantity,
    required super.referenceId,
    required super.note,
    required super.createdBy,
    required super.createdAt,
  });

  factory StockMovementModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return StockMovementModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      movementType: json['movement_type'] as String,
      quantity: (json['quantity'] as num).toInt(),
      previousQuantity:
          (json['previous_quantity'] as num).toInt(),
      newQuantity:
          (json['new_quantity'] as num).toInt(),
      referenceId: json['reference_id'] as String?,
      note: json['note'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String,
      ),
    );
  }
}