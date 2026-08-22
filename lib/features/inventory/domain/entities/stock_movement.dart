class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.referenceId,
    required this.note,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String movementType;
  final int quantity;
  final int previousQuantity;
  final int newQuantity;
  final String? referenceId;
  final String? note;
  final String? createdBy;
  final DateTime createdAt;
}