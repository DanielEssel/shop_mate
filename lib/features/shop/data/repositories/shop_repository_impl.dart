import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/shop_access.dart';
import '../../domain/repositories/shop_repository.dart';

class ShopRepositoryImpl implements ShopRepository {
  ShopRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ShopAccess> fetchAccess(String userId) async {
    // Filter by user_id explicitly: shop owners are also allowed to read the
    // other members of their shop, so RLS alone can return several rows.
    final row = await _client
        .from('shop_members')
        .select('role, status, shops(id, name, status)')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return ShopAccess(userId: userId, status: ShopAccessStatus.noShop);
    }

    final shop = row['shops'];

    if (shop is! Map<String, dynamic>) {
      throw StateError('Membership found without a readable shop record');
    }

    return ShopAccess(
      userId: userId,
      status: _resolveStatus(
        memberStatus: row['status'] as String?,
        shopStatus: shop['status'] as String?,
      ),
      shopId: shop['id'] as String?,
      shopName: shop['name'] as String?,
      role: row['role'] as String?,
    );
  }

  /// Fails closed: anything that is not clearly "active" or "pending" is
  /// treated as suspended.
  ShopAccessStatus _resolveStatus({
    required String? memberStatus,
    required String? shopStatus,
  }) {
    if (memberStatus != 'active') {
      return ShopAccessStatus.suspended;
    }

    return switch (shopStatus) {
      'active' => ShopAccessStatus.active,
      'pending' => ShopAccessStatus.pending,
      _ => ShopAccessStatus.suspended,
    };
  }

  @override
  Future<void> registerShop({
    required String name,
    required String phone,
  }) async {
    await _client.rpc(
      'register_shop',
      params: {'p_name': name, 'p_phone': phone},
    );
  }
}
