import '../../domain/entities/inventory_report.dart';

class InventoryReportModel extends InventoryReport {
  const InventoryReportModel({
    required super.totalProducts,
    required super.totalUnits,
    required super.inventoryCostValue,
    required super.potentialSellingValue,
    required super.expectedGrossProfit,
    required super.lowStockCount,
    required super.outOfStockCount,
    required super.unitsPurchased,
    required super.unitsSold,
  });

  /// Parses the single row returned by `get_inventory_report`.
  factory InventoryReportModel.fromRow(Map<String, Object?> row) {
    return InventoryReportModel(
      totalProducts: _whole(row, 'total_products'),
      totalUnits: _whole(row, 'total_units'),
      inventoryCostValue: _number(row, 'inventory_cost_value'),
      potentialSellingValue: _number(row, 'potential_selling_value'),
      expectedGrossProfit: _number(row, 'expected_gross_profit'),
      lowStockCount: _whole(row, 'low_stock_count'),
      outOfStockCount: _whole(row, 'out_of_stock_count'),
      unitsPurchased: _whole(row, 'units_purchased'),
      unitsSold: _whole(row, 'units_sold'),
    );
  }

  static double _number(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is num && value.isFinite) return value.toDouble();
    // Postgres numeric may arrive as a string for very large values.
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    throw FormatException('Invalid inventory report field: $field.');
  }

  /// Counts and unit totals. Unit totals are Postgres numeric sums of
  /// integer quantities, so they may arrive as strings but must be whole.
  static int _whole(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid inventory report count: $field.');
  }
}
