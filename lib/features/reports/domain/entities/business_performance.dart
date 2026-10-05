import 'package:flutter/foundation.dart';

import 'report_date_range.dart';

/// Profit and loss figures for one date range, as calculated by the
/// database. The app displays these values; it never recalculates them.
@immutable
class BusinessPerformance {
  const BusinessPerformance({
    required this.range,
    required this.totalSales,
    required this.totalCogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.salesCount,
    required this.expenseCount,
  });

  final ReportDateRange range;

  /// Sum of sale totals, including credit sales, in GHS.
  final double totalSales;

  /// Cost of goods sold from the cost recorded on each sale item, in GHS.
  final double totalCogs;

  /// [totalSales] minus [totalCogs].
  final double grossProfit;

  /// Sum of recorded operating expenses, in GHS.
  final double totalExpenses;

  /// [grossProfit] minus [totalExpenses].
  final double netProfit;

  /// Net profit as a percentage of net sales; 0 when there are no sales.
  final double profitMargin;

  final int salesCount;
  final int expenseCount;
}
