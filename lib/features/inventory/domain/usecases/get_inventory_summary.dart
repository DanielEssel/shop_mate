import '../entities/inventory_summary.dart';
import '../repositories/inventory_repository.dart';

class GetInventorySummary {
  GetInventorySummary(this._repository);

  final InventoryRepository _repository;

  Future<InventorySummary> call() {
    return _repository.getInventorySummary();
  }
}
