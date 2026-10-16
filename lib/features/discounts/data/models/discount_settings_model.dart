import '../../domain/entities/discount_percentage.dart';
import '../../domain/entities/discount_scope.dart';
import '../../domain/entities/discount_settings.dart';

class DiscountSettingsModel extends DiscountSettings {
  const DiscountSettingsModel({
    required super.shopId,
    required super.isEnabled,
    required super.scope,
    required super.percentage,
    required super.selectedProductIds,
    super.endsAt,
    super.updatedAt,
  });

  /// A `shop_discount_settings` row plus the shop's selected product ids.
  factory DiscountSettingsModel.fromRow(
    Map<String, Object?> row, {
    required Set<String> selectedProductIds,
  }) {
    final shopId = row['shop_id'];
    final isEnabled = row['is_enabled'];
    final scopeValue = row['scope'];
    if (shopId is! String || isEnabled is! bool || scopeValue is! String) {
      throw const FormatException('Invalid discount settings row.');
    }
    final scope = DiscountScope.fromValue(scopeValue);
    if (scope == null) {
      throw FormatException('Unknown discount scope: $scopeValue.');
    }

    return DiscountSettingsModel(
      shopId: shopId,
      isEnabled: isEnabled,
      scope: scope,
      percentage: DiscountPercentage.fromDatabase(row['percentage']),
      endsAt: _optionalTimestamp(row['ends_at']),
      updatedAt: _optionalTimestamp(row['updated_at']),
      selectedProductIds: selectedProductIds,
    );
  }

  static DateTime? _optionalTimestamp(Object? value) {
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      throw const FormatException('Invalid discount settings timestamp.');
    }
    return parsed;
  }
}
