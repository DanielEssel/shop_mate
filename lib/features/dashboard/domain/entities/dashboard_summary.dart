import 'package:flutter/foundation.dart';
import '../entities/recent_sale.dart';

@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayProfit,
    required this.todayTransactions,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.recentSales,
  });

  final double todaySales;
  final double todayProfit;
  final int todayTransactions;
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final List<DashboardRecentSale> recentSales;
}

