import 'package:flutter/foundation.dart';

import 'shop_branding.dart';
import 'shop_branding_exception.dart';

/// Branding plus the downloaded logo. A logo that fails to download does not
/// make branding unavailable: [logoBytes] is null and [logoError] says why,
/// so consumers can fall back to the shop name.
@immutable
class ShopBrandingResult {
  const ShopBrandingResult({
    required this.branding,
    this.logoBytes,
    this.logoError,
    this.cleanupError,
  });

  final ShopBranding branding;

  /// The logo image, when the shop has one and it downloaded.
  final Uint8List? logoBytes;

  /// Set when the shop has a logo but it could not be downloaded.
  final ShopBrandingException? logoError;

  /// Set when a logo change succeeded but the previous image could not be
  /// deleted from storage. The change itself still stands.
  final ShopBrandingException? cleanupError;
}
