import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/admin_shop.dart';
import '../models/admin_shop_model.dart';

/// The platform admin RPCs. Each one checks `is_platform_admin()` in the
/// database and raises 42501 for anyone else; nothing here is trusted to
/// enforce access.
class AdminRemoteDataSource {
  AdminRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<bool> isPlatformAdmin() async {
    final Object? response = await _client.rpc('is_platform_admin');
    if (response is! bool) {
      throw const FormatException('Invalid is_platform_admin response.');
    }
    return response;
  }

  Future<List<AdminShopModel>> getShops(AdminShopStatus status) async {
    final Object? response = await _client.rpc(
      'admin_list_shops',
      params: {'p_status': status.value},
    );
    if (response is! List) {
      throw const FormatException('Invalid admin_list_shops response.');
    }

    return [
      for (final Object? row in response)
        if (row is Map)
          AdminShopModel.fromRow(Map<String, Object?>.from(row))
        else
          throw const FormatException('Invalid admin_list_shops row.'),
    ];
  }

  Future<void> approveShop(String shopId) =>
      _change('admin_approve_shop', shopId);

  Future<void> suspendShop(String shopId) =>
      _change('admin_suspend_shop', shopId);

  Future<void> reactivateShop(String shopId) =>
      _change('admin_reactivate_shop', shopId);

  Future<void> _change(String function, String shopId) async {
    await _client.rpc(function, params: {'p_shop_id': shopId});
  }
}
