import 'package:flutter/foundation.dart';

import '../../../shop/domain/entities/shop_branding_result.dart';

/// Shop identity printed on a receipt. A plain value, so receipt generation
/// never depends on Riverpod or Supabase.
@immutable
class ReceiptBranding {
  const ReceiptBranding({this.shopName, this.phone, this.logoBytes});

  /// Builds receipt branding from the current shop branding. While branding
  /// is unavailable, [fallbackShopName] (the shop access name) keeps the
  /// receipt titled. A logo that failed to download is simply absent.
  factory ReceiptBranding.from({
    ShopBrandingResult? branding,
    String? fallbackShopName,
  }) {
    if (branding == null) {
      return ReceiptBranding(shopName: _clean(fallbackShopName));
    }

    return ReceiptBranding(
      shopName: _clean(branding.branding.name) ?? _clean(fallbackShopName),
      phone: _clean(branding.branding.phone),
      logoBytes: branding.logoBytes,
    );
  }

  final String? shopName;
  final String? phone;
  final Uint8List? logoBytes;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Logo bytes compare by identity: the branding provider hands out a new
  /// buffer whenever the logo changes.
  @override
  bool operator ==(Object other) {
    return other is ReceiptBranding &&
        other.shopName == shopName &&
        other.phone == phone &&
        identical(other.logoBytes, logoBytes);
  }

  @override
  int get hashCode => Object.hash(shopName, phone, identityHashCode(logoBytes));
}
