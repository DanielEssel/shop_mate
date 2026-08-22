import '../../domain/entities/inventory_summary.dart';

class InventorySummaryModel extends InventorySummary {
  const InventorySummaryModel({
    required super.totalProducts,
    required super.totalStockUnits,
    required super.lowStockProducts,
    required super.outOfStockProducts,
  });

  factory InventorySummaryModel.fromProducts(
    List<Map<String, dynamic>> products,
  ) {
    int totalStockUnits = 0;
    int lowStockProducts = 0;
    int outOfStockProducts = 0;

    for (final product in products) {
      final stock =
          (product['stock_quantity'] as num?)?.toInt() ?? 0;

      final threshold =
          (product['low_stock_threshold'] as num?)?.toInt() ?? 10;

      totalStockUnits += stock;

      if (stock <= 0) {
        outOfStockProducts++;
      } else if (stock <= threshold) {
        lowStockProducts++;
      }
    }

    return InventorySummaryModel(
      totalProducts: products.length,
      totalStockUnits: totalStockUnits,
      lowStockProducts: lowStockProducts,
      outOfStockProducts: outOfStockProducts,
    );
  }
}
