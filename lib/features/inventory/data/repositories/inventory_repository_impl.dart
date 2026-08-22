import '../../domain/entities/inventory_summary.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_datasource.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._remoteDataSource);

  final InventoryRemoteDataSource _remoteDataSource;

  @override
  Future<InventorySummary> getInventorySummary() {
    return _remoteDataSource.getInventorySummary();
  }

  @override
  Future<String> adjustStock({
    required String productId,
    required int quantity,
    required String direction,
    String? note,
  }) {
    return _remoteDataSource.adjustStock(
      productId: productId,
      quantity: quantity,
      direction: direction,
      note: note,
    );
  }

  @override
  Future<List<StockMovement>> getStockMovements({
    String? productId,
  }) {
    return _remoteDataSource.getStockMovements(
      productId: productId,
    );
  }
}
