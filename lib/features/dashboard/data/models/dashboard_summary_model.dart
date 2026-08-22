import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/recent_sale.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.todaySales,
    required super.todayProfit,
    required super.todayTransactions,
    required super.totalProducts,
    required super.lowStockProducts,
    required super.outOfStockProducts,
    required super.recentSales,
  });

  factory DashboardSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final recentSalesJson =
        (json['recent_sales'] as List?) ?? [];

    return DashboardSummaryModel(
      todaySales:
          (json['today_sales'] as num?)?.toDouble() ?? 0,
      todayProfit:
          (json['today_profit'] as num?)?.toDouble() ?? 0,
      todayTransactions:
          (json['today_transactions'] as num?)?.toInt() ?? 0,
      totalProducts:
          (json['total_products'] as num?)?.toInt() ?? 0,
      lowStockProducts:
          (json['low_stock_products'] as num?)?.toInt() ?? 0,
      outOfStockProducts:
          (json['out_of_stock_products'] as num?)?.toInt() ?? 0,
      recentSales: recentSalesJson
          .map(
            (item) => DashboardRecentSale(
              id: item['id'] as String,
              saleNumber:
                  item['sale_number'] as String,
              totalAmount:
                  (item['total_amount'] as num).toDouble(),
              paymentMethod:
                  item['payment_method'] as String,
              createdAt:
                  DateTime.parse(
                item['created_at'].toString(),
              ),
              itemCount:
                  (item['item_count'] as num).toInt(),
            ),
          )
          .toList(),
    );
  }
}