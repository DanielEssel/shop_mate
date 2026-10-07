import '../repositories/admin_repository.dart';

class SuspendShop {
  SuspendShop(this._repository);

  final AdminRepository _repository;

  Future<void> call(String shopId) {
    return _repository.suspendShop(shopId);
  }
}
