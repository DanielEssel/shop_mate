import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/report_date_range.dart';
import '../models/business_performance_model.dart';
import '../models/inventory_report_model.dart';

class ReportRemoteDataSource {
  ReportRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Calls `get_business_performance`, which scopes every figure to the
  /// caller's active shop; no shop id is sent.
  Future<BusinessPerformanceModel> getBusinessPerformance(
    ReportDateRange range,
  ) async {
    final response = await _client.rpc(
      'get_business_performance',
      params: {
        'p_start_date': _dateOnly(range.start),
        'p_end_date': _dateOnly(range.end),
      },
    );

    // The function returns a single-row table.
    if (response is! List || response.length != 1 || response.first is! Map) {
      throw const FormatException('Invalid business performance response.');
    }

    return BusinessPerformanceModel.fromRow(
      Map<String, Object?>.from(response.first as Map),
      range: range,
    );
  }

  /// Calls `get_inventory_report`, which scopes every figure to the caller's
  /// active shop; no shop id is sent.
  Future<InventoryReportModel> getInventoryReport() async {
    final response = await _client.rpc('get_inventory_report');

    // The function returns a single-row table.
    if (response is! List || response.length != 1 || response.first is! Map) {
      throw const FormatException('Invalid inventory report response.');
    }

    return InventoryReportModel.fromRow(
      Map<String, Object?>.from(response.first as Map),
    );
  }

  /// Formats the local calendar date as `yyyy-MM-dd` without a UTC shift.
  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }
}
