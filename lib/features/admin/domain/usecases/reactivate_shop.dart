import '../repositories/admin_repository.dart';

class ReactivateShop {
  ReactivateShop(this._repository);

  final AdminRepository _repository;

  Future<void> call(String shopId) {
    return _repository.reactivateShop(shopId);
  }
}
