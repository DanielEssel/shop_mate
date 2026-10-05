import '../entities/business_performance.dart';
import '../entities/inventory_report.dart';
import '../entities/report_date_range.dart';

abstract class ReportRepository {
  Future<BusinessPerformance> getBusinessPerformance(ReportDateRange range);

  Future<InventoryReport> getInventoryReport();
}
