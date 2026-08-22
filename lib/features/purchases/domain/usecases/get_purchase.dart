import '../entities/purchase.dart';
import '../repositories/purchase_repository.dart';

class GetPurchase {
  const GetPurchase(this._repository);

  final PurchaseRepository _repository;

  Future<Purchase> call(String id) {
    return _repository.getPurchaseById(id);
  }
}