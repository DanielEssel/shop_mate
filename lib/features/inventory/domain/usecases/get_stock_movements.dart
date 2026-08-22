import '../entities/stock_movement.dart';
import '../repositories/inventory_repository.dart';

class GetStockMovements {
  GetStockMovements(this._repository);

  final InventoryRepository _repository;

  Future<List<StockMovement>> call({
    String? productId,
  }) {
    return _repository.getStockMovements(
      productId: productId,
    );
  }
}
