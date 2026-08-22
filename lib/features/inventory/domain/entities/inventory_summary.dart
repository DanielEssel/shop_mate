class InventorySummary {
  const InventorySummary({
    required this.totalProducts,
    required this.totalStockUnits,
    required this.lowStockProducts,
    required this.outOfStockProducts,
  });

  final int totalProducts;
  final int totalStockUnits;
  final int lowStockProducts;
  final int outOfStockProducts;
}
