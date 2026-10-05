import '../../domain/entities/shop_branding.dart';

class ShopBrandingModel extends ShopBranding {
  const ShopBrandingModel({
    required super.shopId,
    required super.name,
    super.phone,
    super.logoPath,
  });

  /// Columns read from `public.shops`.
  static const selectColumns = 'id, name, phone, logo_path';

  factory ShopBrandingModel.fromRow(Map<String, Object?> row) {
    return ShopBrandingModel(
      shopId: _string(row, 'id'),
      name: _string(row, 'name'),
      phone: _optionalString(row, 'phone'),
      logoPath: _optionalString(row, 'logo_path'),
    );
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid shop branding field: $field.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid shop branding field: $field.');
    }
    return value;
  }
}
