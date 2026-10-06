import '../entities/shop_branding_result.dart';
import '../entities/shop_logo_upload.dart';
import '../entities/shop_profile_update.dart';

/// Branding for the caller's current shop. [shopId] comes from the signed-in
/// shop context, never from user input; RLS and the branding RPCs enforce it.
/// Failures are thrown as `ShopBrandingException`.
abstract class ShopBrandingRepository {
  Future<ShopBrandingResult> getShopBranding(String shopId);

  /// Uploads [upload] as the new logo, points the shop at it, then deletes
  /// the previous logo object.
  Future<ShopBrandingResult> uploadLogo(String shopId, ShopLogoUpload upload);

  /// Clears the shop logo, then deletes the previous logo object.
  Future<ShopBrandingResult> removeLogo(String shopId);

  /// Saves the business name and phone (owner only), then re-reads branding.
  Future<ShopBrandingResult> updateProfile(
    String shopId,
    ShopProfileUpdate update,
  );
}
