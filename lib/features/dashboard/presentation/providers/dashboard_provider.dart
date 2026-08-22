import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary.dart';

final dashboardRemoteDataSourceProvider =
    Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(
    SupabaseService.client,
  );
});

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    ref.read(dashboardRemoteDataSourceProvider),
  );
});

final getDashboardSummaryProvider =
    Provider<GetDashboardSummary>((ref) {
  return GetDashboardSummary(
    ref.read(dashboardRepositoryProvider),
  );
});

final dashboardSummaryProvider =
    FutureProvider<DashboardSummary>((ref) {
  return ref
      .read(getDashboardSummaryProvider)
      .call();
});