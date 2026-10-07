import '../entities/admin_shop.dart';
import '../repositories/admin_repository.dart';

class GetAdminShops {
  GetAdminShops(this._repository);

  final AdminRepository _repository;

  Future<List<AdminShop>> call(AdminShopStatus status) {
    return _repository.getShops(status);
  }
}
