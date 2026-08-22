import '../repositories/inventory_repository.dart';

class AdjustStock {
  AdjustStock(this._repository);

  final InventoryRepository _repository;

  Future<String> call({
    required String productId,
    required int quantity,
    required String direction,
    String? note,
  }) {
    return _repository.adjustStock(
      productId: productId,
      quantity: quantity,
      direction: direction,
      note: note,
    );
  }
}