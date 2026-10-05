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
  };
}
