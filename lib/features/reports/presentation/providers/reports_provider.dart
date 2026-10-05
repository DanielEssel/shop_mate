import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/entities/business_performance.dart';
import '../../domain/entities/inventory_report.dart';
import '../../domain/entities/report_date_range.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/get_business_performance.dart';
import '../../domain/usecases/get_inventory_report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final dataSource = ReportRemoteDataSource(SupabaseService.client);

  return ReportRepositoryImpl(dataSource);
});

final getBusinessPerformanceProvider = Provider<GetBusinessPerformance>((ref) {
  return GetBusinessPerformance(ref.read(reportRepositoryProvider));
});

/// Business performance for one date range. Ranges compare by value, so the
/// same range reuses the same result until invalidated.
final businessPerformanceProvider = FutureProvider.autoDispose
    .family<BusinessPerformance, ReportDateRange>((ref, range) {
      return ref.read(getBusinessPerformanceProvider).call(range);
    });

final getInventoryReportProvider = Provider<GetInventoryReport>((ref) {
  return GetInventoryReport(ref.read(reportRepositoryProvider));
});

/// Current inventory report for the active shop. Auto-disposed so reopening
/// the report re-reads live stock instead of reusing a stale snapshot.
final inventoryReportProvider = FutureProvider.autoDispose<InventoryReport>((
  ref,
) {
  return ref.read(getInventoryReportProvider).call();
});
