import '../../domain/entities/business_performance.dart';
import '../../domain/entities/inventory_report.dart';
import '../../domain/entities/report_date_range.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._remoteDataSource);

  final ReportRemoteDataSource _remoteDataSource;

  @override
  Future<BusinessPerformance> getBusinessPerformance(ReportDateRange range) {
    return _remoteDataSource.getBusinessPerformance(range);
  }

  @override
  Future<InventoryReport> getInventoryReport() {
    return _remoteDataSource.getInventoryReport();
  }
}
