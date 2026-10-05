import '../entities/business_performance.dart';
import '../entities/report_date_range.dart';
import '../repositories/report_repository.dart';

class GetBusinessPerformance {
  GetBusinessPerformance(this._repository);

  final ReportRepository _repository;

  Future<BusinessPerformance> call(ReportDateRange range) {
    return _repository.getBusinessPerformance(range);
  }
}
