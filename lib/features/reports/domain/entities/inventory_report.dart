import 'package:flutter/foundation.dart';

/// Stock-on-hand valuation and all-time stock flow for the active shop, as
/// calculated by the database. The app displays these values; it never
/// recalculates them.
@immutable
class InventoryReport {
  const InventoryReport({
    required this.totalProducts,
    required this.totalUnits,
    required this.inventoryCostValue,
    required this.potentialSellingValue,
    required this.expectedGrossProfit,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.unitsPurchased,
    required this.unitsSold,
  });

  /// Active products, including those with zero stock.
  final int totalProducts;

  /// Units currently in stock across active products.
  final int totalUnits;

  /// Stock on hand valued at current product cost prices, in GHS.
  final double inventoryCostValue;

  /// Stock on hand valued at current product selling prices, in GHS.
  final double potentialSellingValue;

  /// [potentialSellingValue] minus [inventoryCostValue].
  final double expectedGrossProfit;

  /// Products in stock at or below their low-stock threshold.
  final int lowStockCount;

  /// Products with zero stock.
  final int outOfStockCount;

  /// Units on all completed purchases.
  final int unitsPurchased;

  /// Units on all sales, including credit sales.
  final int unitsSold;
}
