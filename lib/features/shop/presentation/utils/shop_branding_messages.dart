import '../../domain/entities/shop_branding_exception.dart';

/// User-facing wording for branding failures on the Settings screen. Raw
/// backend errors are never shown.
String shopBrandingErrorMessage(ShopBrandingException error) {
  return switch (error.kind) {
    ShopBrandingErrorKind.permissionDenied =>
      "You don't have permission to change the shop logo.",
    ShopBrandingErrorKind.invalidFormat => 'Choose a PNG or JPEG image.',
    ShopBrandingErrorKind.tooLarge => 'Logo must be 1 MB or smaller.',
    ShopBrandingErrorKind.emptyFile => 'The selected image is empty.',
    ShopBrandingErrorKind.uploadFailed =>
      "We couldn't update the shop logo. Please try again.",
    ShopBrandingErrorKind.removeFailed =>
      "We couldn't remove the shop logo. Please try again.",
    ShopBrandingErrorKind.unavailable =>
      'Shop information is temporarily unavailable.',
    ShopBrandingErrorKind.logoUnavailable => "Logo couldn't be loaded.",
    ShopBrandingErrorKind.cleanupFailed =>
      'The logo was updated, but the previous image could not be deleted.',
    ShopBrandingErrorKind.invalidName =>
      'Business name must be 2 to 80 characters.',
    ShopBrandingErrorKind.invalidPhone => 'Enter a valid phone number.',
    ShopBrandingErrorKind.profileUpdateFailed =>
      "We couldn't save the business profile. Please try again.",
  };
}

/// Wording for business name/phone failures; a permission failure names the
/// business profile rather than the logo.
String shopProfileErrorMessage(ShopBrandingException error) {
  if (error.kind == ShopBrandingErrorKind.permissionDenied) {
    return "You don't have permission to change the business profile.";
  }
  return shopBrandingErrorMessage(error);
}
