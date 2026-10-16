import 'package:flutter/foundation.dart';

import '../../../products/domain/entities/product.dart';
import 'discount_percentage.dart';
import 'discount_scope.dart';
import 'discount_settings.dart';

/// One product's price under a discount, in whole pesewas (cents).
///
/// For previews and warnings only: the server decides what a sale charges.
@immutable
class DiscountedPrice {
  const DiscountedPrice({
    required this.originalCents,
    required this.costCents,
    required this.discountCents,
  });

  final int originalCents;
  final int costCents;

  /// Per-unit discount, rounded like the database.
  final int discountCents;

  int get finalCents => originalCents - discountCents;

  /// A discount that would take the price below the current cost. A product
  /// already priced below cost with no discount is not "below cost" here,
  /// matching the server.
  bool get isBelowCost => discountCents > 0 && finalCents < costCents;

  /// How far below cost the discounted price would be (0 when it isn't).
  int get shortfallCents => isBelowCost ? costCents - finalCents : 0;
}

/// What checkout expects one product to cost under the shop's discount.
///
/// An estimate for display: the server applies the configuration current
/// when the sale is recorded, and its recorded totals are what count.
@immutable
class LineDiscountPreview {
  const LineDiscountPreview({
    required this.originalCents,
    required this.discountCents,
    required this.percentageBasisPoints,
    required this.likelyRefused,
  });

  /// No discount applies.
  const LineDiscountPreview.none(this.originalCents)
    : discountCents = 0,
      percentageBasisPoints = 0,
      likelyRefused = false;

  final int originalCents;

  /// Per-unit discount (0 when none applies).
  final int discountCents;

  /// The percentage applied, in hundredths (0 when no money comes off).
  final int percentageBasisPoints;

  /// A selected-products discount would take this product below cost, so
  /// the server will refuse the sale (SQLSTATE SMD01) while it is on.
  final bool likelyRefused;

  int get finalCents => originalCents - discountCents;

  bool get isDiscounted => discountCents > 0;

  /// e.g. `10%`, or null when no money comes off.
  String? get percentageLabel => percentageBasisPoints > 0
      ? DiscountPercentage.fromBasisPoints(percentageBasisPoints).label
      : null;
}

/// A product the discount would take below its cost.
@immutable
class BelowCostProduct {
  const BelowCostProduct({required this.product, required this.price});

  final Product product;
  final DiscountedPrice price;
}

/// The database's discount rule, in integer arithmetic.
///
/// `create_sale` computes `round(selling_price * percentage / 100, 2)` with
/// PostgreSQL numeric rounding (half away from zero) and subtracts it from
/// the selling price. Prices are stored with two decimals, so they are
/// converted to exact integer cents first; no floating-point result is ever
/// used as a price.
abstract final class DiscountPricing {
  /// Exact cents for a stored two-decimal amount.
  static int toCents(double amount) => (amount * 100).round();

  /// The per-unit discount in cents for [priceCents] at [percentage].
  static int discountCents(int priceCents, DiscountPercentage percentage) {
    // price (cents) x percentage (hundredths of a percent) / 10000 = cents.
    final scaled = priceCents * percentage.basisPoints;
    final whole = scaled ~/ 10000;
    final remainder = scaled % 10000;
    // Half away from zero; prices are never negative.
    return remainder * 2 >= 10000 ? whole + 1 : whole;
  }

  static DiscountedPrice priceOf(
    Product product,
    DiscountPercentage percentage,
  ) {
    final originalCents = toCents(product.sellingPrice);
    return DiscountedPrice(
      originalCents: originalCents,
      costCents: toCents(product.costPrice),
      discountCents: discountCents(originalCents, percentage),
    );
  }

  /// Checkout's estimate for [product] under [settings] at [now], following
  /// `create_sale`: no active configuration, or a product outside the
  /// selection, means no discount; a discount that would go below cost
  /// means full price for all products, and a refused sale for selected
  /// products.
  static LineDiscountPreview preview(
    Product product, {
    required DiscountSettings? settings,
    required DateTime now,
  }) {
    final originalCents = toCents(product.sellingPrice);
    if (settings == null || !settings.isActiveAt(now)) {
      return LineDiscountPreview.none(originalCents);
    }
    final covered =
        settings.scope == DiscountScope.allProducts ||
        settings.selectedProductIds.contains(product.id);
    if (!covered) return LineDiscountPreview.none(originalCents);

    final price = priceOf(product, settings.percentage);
    if (price.isBelowCost) {
      return LineDiscountPreview(
        originalCents: originalCents,
        discountCents: 0,
        percentageBasisPoints: 0,
        likelyRefused: settings.scope == DiscountScope.selectedProducts,
      );
    }
    return LineDiscountPreview(
      originalCents: originalCents,
      discountCents: price.discountCents,
      percentageBasisPoints: price.discountCents > 0
          ? settings.percentage.basisPoints
          : 0,
      likelyRefused: false,
    );
  }

  /// The products in [products] that [scope] covers and that [percentage]
  /// would take below cost, ordered by name.
  ///
  /// [DiscountScope.allProducts]: such products sell at their normal price.
  /// [DiscountScope.selectedProducts]: such products refuse the sale, so
  /// the configuration must not be saved.
  static List<BelowCostProduct> belowCost({
    required List<Product> products,
    required DiscountScope scope,
    required Set<String> selectedProductIds,
    required DiscountPercentage percentage,
  }) {
    final unsafe = <BelowCostProduct>[];
    for (final product in products) {
      if (scope == DiscountScope.selectedProducts &&
          !selectedProductIds.contains(product.id)) {
        continue;
      }
      final price = priceOf(product, percentage);
      if (price.isBelowCost) {
        unsafe.add(BelowCostProduct(product: product, price: price));
      }
    }
    unsafe.sort(
      (a, b) =>
          a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()),
    );
    return unsafe;
  }
}
