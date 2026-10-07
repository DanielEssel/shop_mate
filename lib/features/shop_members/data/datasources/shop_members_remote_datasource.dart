import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/new_shop_attendant.dart';
import '../../domain/entities/shop_member.dart';
import '../models/created_shop_attendant_model.dart';
import '../models/shop_member_model.dart';

/// The owner's member-management RPCs and the `create-shop-attendant` Edge
/// Function. Each one checks on the server that the caller is the active
/// owner of an active shop; nothing here is trusted to enforce access.
class ShopMembersRemoteDataSource {
  ShopMembersRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<ShopMemberModel>> getMembers() async {
    final Object? response = await _client.rpc('list_shop_members');
    if (response is! List) {
      throw const FormatException('Invalid list_shop_members response.');
    }

    return [
      for (final Object? row in response)
        if (row is Map)
          ShopMemberModel.fromRow(Map<String, Object?>.from(row))
        else
          throw const FormatException('Invalid list_shop_members row.'),
    ];
  }

  /// Sent with the caller's own session token; the Edge Function derives the
  /// shop and the 'staff' role on the server.
  Future<CreatedShopAttendantModel> createAttendant(
    NewShopAttendant attendant,
  ) async {
    final response = await _client.functions.invoke(
      'create-shop-attendant',
      body: <String, String>{
        'email': attendant.email,
        'display_name': attendant.displayName,
        'temporary_password': attendant.temporaryPassword,
      },
    );
    final Object? data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid create-shop-attendant response.');
    }
    return CreatedShopAttendantModel.fromJson(Map<String, Object?>.from(data));
  }

  Future<void> setMemberStatus(
    String memberUserId,
    ShopMemberStatus status,
  ) async {
    await _client.rpc(
      'set_shop_member_status',
      params: {'p_member_user_id': memberUserId, 'p_status': status.value},
    );
  }

  Future<void> removeMember(String memberUserId) async {
    await _client.rpc(
      'remove_shop_member',
      params: {'p_member_user_id': memberUserId},
    );
  }
}
