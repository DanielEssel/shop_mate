import '../../../products/domain/entities/product.dart';
import '../entities/discount_pricing.dart';
import '../entities/discount_scope.dart';
import '../entities/discount_settings.dart';
import '../entities/discount_settings_exception.dart';
import '../repositories/discount_settings_repository.dart';

/// Validates and saves the owner's discount configuration.
///
/// Nothing is sent while the release gate is closed ([writesEnabled]
/// false). The below-cost check uses the products as currently loaded; the
/// server checks again on every sale, because costs can change later.
class SaveDiscountSettings {
  SaveDiscountSettings(this._repository, {required this.writesEnabled});

  final DiscountSettingsRepository _repository;
  final bool writesEnabled;

  Future<void> call(
    DiscountSettingsDraft draft, {
    required DiscountSettings? current,
    required List<Product> products,
    required DateTime now,
  }) async {
    if (!writesEnabled) {
      throw const DiscountSettingsException(
        DiscountSettingsErrorKind.writesNotAvailable,
      );
    }

    final endsAt = draft.endsAt;
    if (draft.isEnabled && endsAt != null && !endsAt.isAfter(now)) {
      throw const DiscountSettingsException(
        DiscountSettingsErrorKind.endDateInPast,
      );
    }

    if (draft.scope == DiscountScope.selectedProducts) {
      if (draft.isEnabled && draft.selectedProductIds.isEmpty) {
        throw const DiscountSettingsException(
          DiscountSettingsErrorKind.noProductsSelected,
        );
      }
      final unsafe = DiscountPricing.belowCost(
        products: products,
        scope: draft.scope,
        selectedProductIds: draft.selectedProductIds,
        percentage: draft.percentage,
      );
      if (unsafe.isNotEmpty) {
        throw const DiscountSettingsException(
          DiscountSettingsErrorKind.unsafeSelection,
        );
      }
    }

    await _repository.saveSettings(draft, current: current);
  }
}
