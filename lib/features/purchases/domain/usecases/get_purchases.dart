import '../entities/purchase.dart';
import '../repositories/purchase_repository.dart';

class GetPurchases {
  const GetPurchases(this._repository);

  final PurchaseRepository _repository;

  Future<List<Purchase>> call() {
    return _repository.getPurchases();
  }
}