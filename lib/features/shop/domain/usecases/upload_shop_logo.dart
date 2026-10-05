import '../entities/shop_branding_result.dart';
import '../entities/shop_logo_upload.dart';
import '../repositories/shop_branding_repository.dart';

class UploadShopLogo {
  UploadShopLogo(this._repository);

  final ShopBrandingRepository _repository;

  Future<ShopBrandingResult> call(String shopId, ShopLogoUpload upload) {
    return _repository.uploadLogo(shopId, upload);
  }
}
