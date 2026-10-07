import '../repositories/admin_repository.dart';

class ApproveShop {
  ApproveShop(this._repository);

  final AdminRepository _repository;

  Future<void> call(String shopId) {
    return _repository.approveShop(shopId);
  }
}
