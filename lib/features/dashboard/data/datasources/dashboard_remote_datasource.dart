import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_summary_model.dart';

class DashboardRemoteDataSource {
  DashboardRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<DashboardSummaryModel> getDashboardSummary() async {
    final response = await _client.rpc(
      'get_dashboard_summary',
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid dashboard response.',
      );
    }

    return DashboardSummaryModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}