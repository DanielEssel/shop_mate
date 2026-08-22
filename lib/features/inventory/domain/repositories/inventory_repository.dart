import '../entities/inventory_summary.dart';
import '../entities/stock_movement.dart';

abstract class InventoryRepository {
  Future<InventorySummary> getInventorySummary();

  Future<String> adjustStock({
    required String productId,
    required int quantity,
    required String direction,
    String? note,
  });

  Future<List<StockMovement>> getStockMovements({
    String? productId,
  });
}
