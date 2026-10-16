import 'dart:async';

import 'package:shopmate/features/discounts/domain/entities/discount_percentage.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings_exception.dart';
import 'package:shopmate/features/discounts/domain/repositories/discount_settings_repository.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';

Product discountProduct(
  String id,
  String name, {
  required double price,
  required double cost,
  String? sku,
}) {
  return Product(
    id: id,
    name: name,
    costPrice: cost,
    sellingPrice: price,
    stockQuantity: 50,
    lowStockThreshold: 5,
    sku: sku,
  );
}

/// The products used across the discount tests (same prices and costs as
/// the database tests).
final discountProducts = [
  discountProduct('rice', 'Rice 1kg', price: 10.00, cost: 6.00, sku: 'RC-1'),
  discountProduct('oil', 'Oil 1L', price: 19.99, cost: 5.00),
  discountProduct('sugar', 'Sugar', price: 7.00, cost: 6.80),
  discountProduct('sweet', 'Sweet', price: 0.33, cost: 0.10),
  discountProduct('mint', 'Mint', price: 0.10, cost: 0.00),
  discountProduct('loss', 'Loss leader', price: 4.00, cost: 5.00),
];

DiscountSettings discountSettings({
  bool isEnabled = true,
  DiscountScope scope = DiscountScope.allProducts,
  int basisPoints = 1000,
  DateTime? endsAt,
  Set<String> selectedProductIds = const {},
}) {
  return DiscountSettings(
    shopId: 'shop-1',
    isEnabled: isEnabled,
    scope: scope,
    percentage: DiscountPercentage.fromBasisPoints(basisPoints),
    endsAt: endsAt,
    selectedProductIds: selectedProductIds,
    updatedAt: DateTime.utc(2026, 10, 15),
  );
}

/// In-memory stand-in: returns [settings], records every save.
class FakeDiscountSettingsRepository implements DiscountSettingsRepository {
  FakeDiscountSettingsRepository({this.settings});

  DiscountSettings? settings;

  final saves = <DiscountSettingsDraft>[];
  int loads = 0;

  /// The next load fails with this, once.
  DiscountSettingsException? loadError;

  /// While set, loads wait for it.
  Completer<void>? loadGate;

  /// The next save fails with this, once.
  DiscountSettingsException? saveError;

  /// While set, saves wait for it.
  Completer<void>? saveGate;

  @override
  Future<DiscountSettings?> getSettings() async {
    loads++;
    await loadGate?.future;
    final error = loadError;
    if (error != null) {
      loadError = null;
      throw error;
    }
    return settings;
  }

  @override
  Future<void> saveSettings(
    DiscountSettingsDraft draft, {
    required DiscountSettings? current,
  }) async {
    saves.add(draft);
    await saveGate?.future;
    final error = saveError;
    if (error != null) {
      saveError = null;
      throw error;
    }
    settings = DiscountSettings(
      shopId: 'shop-1',
      isEnabled: draft.isEnabled,
      scope: draft.scope,
      percentage: draft.percentage,
      endsAt: draft.endsAt,
      selectedProductIds: draft.selectedProductIds,
    );
  }
}
