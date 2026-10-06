import '../entities/shop_branding_result.dart';
import '../entities/shop_profile_update.dart';
import '../repositories/shop_branding_repository.dart';

class UpdateShopProfile {
  UpdateShopProfile(this._repository);

  final ShopBrandingRepository _repository;

  Future<ShopBrandingResult> call(String shopId, ShopProfileUpdate update) {
    return _repository.updateProfile(shopId, update);
  }
}
