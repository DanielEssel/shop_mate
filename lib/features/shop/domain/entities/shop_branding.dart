import 'package:flutter/foundation.dart';

/// The current shop's identity for display and documents. The logo itself
/// is kept out of the entity; [logoPath] only names the stored object.
@immutable
class ShopBranding {
  const ShopBranding({
    required this.shopId,
    required this.name,
    this.phone,
    this.logoPath,
  });

  final String shopId;
  final String name;
  final String? phone;

  /// Object path in the private `shop-branding` bucket, or null when the
  /// shop has no logo.
  final String? logoPath;

  bool get hasLogo => logoPath != null;
}
