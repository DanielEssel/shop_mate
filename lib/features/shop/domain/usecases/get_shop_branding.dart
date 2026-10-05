import '../entities/shop_branding_result.dart';
import '../repositories/shop_branding_repository.dart';

class GetShopBranding {
  GetShopBranding(this._repository);

  final ShopBrandingRepository _repository;

  Future<ShopBrandingResult> call(String shopId) {
    return _repository.getShopBranding(shopId);
  }
}
