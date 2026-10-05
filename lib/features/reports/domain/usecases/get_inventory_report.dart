import '../entities/inventory_report.dart';
import '../repositories/report_repository.dart';

class GetInventoryReport {
  GetInventoryReport(this._repository);

  final ReportRepository _repository;

  Future<InventoryReport> call() {
    return _repository.getInventoryReport();
  }
}
