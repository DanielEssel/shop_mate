import '../../domain/entities/business_performance.dart';
import '../../domain/entities/report_date_range.dart';

class BusinessPerformanceModel extends BusinessPerformance {
  const BusinessPerformanceModel({
    required super.range,
    required super.totalSales,
    required super.totalCogs,
    required super.grossProfit,
    required super.totalExpenses,
    required super.netProfit,
    required super.profitMargin,
    required super.salesCount,
    required super.expenseCount,
  });

  /// Parses the single row returned by `get_business_performance`.
  factory BusinessPerformanceModel.fromRow(
    Map<String, Object?> row, {
    required ReportDateRange range,
  }) {
    return BusinessPerformanceModel(
      range: range,
      totalSales: _number(row, 'total_sales'),
      totalCogs: _number(row, 'total_cogs'),
      grossProfit: _number(row, 'gross_profit'),
      totalExpenses: _number(row, 'total_expenses'),
      netProfit: _number(row, 'net_profit'),
      profitMargin: _number(row, 'profit_margin'),
      salesCount: _count(row, 'sales_count'),
      expenseCount: _count(row, 'expense_count'),
    );
  }

  static double _number(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is num) return value.toDouble();
    // Postgres numeric may arrive as a string for very large values.
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    throw FormatException('Invalid business performance field: $field.');
  }

  static int _count(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid business performance count: $field.');
  }
}
