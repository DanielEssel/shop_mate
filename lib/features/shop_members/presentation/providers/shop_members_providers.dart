import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/shop_members_remote_datasource.dart';
import '../../data/repositories/shop_members_repository_impl.dart';
import '../../domain/entities/shop_member.dart';
import '../../domain/repositories/shop_members_repository.dart';
import '../../domain/usecases/create_shop_attendant.dart';
import '../../domain/usecases/get_shop_members.dart';
import '../../domain/usecases/restore_shop_member.dart';
import '../../domain/usecases/revoke_shop_member.dart';
import '../../domain/usecases/suspend_shop_member.dart';

final shopMembersRepositoryProvider = Provider<ShopMembersRepository>((ref) {
  return ShopMembersRepositoryImpl(
    ShopMembersRemoteDataSource(ref.read(supabaseClientProvider)),
  );
});

final getShopMembersProvider = Provider<GetShopMembers>((ref) {
  return GetShopMembers(ref.read(shopMembersRepositoryProvider));
});

final createShopAttendantProvider = Provider<CreateShopAttendant>((ref) {
  return CreateShopAttendant(ref.read(shopMembersRepositoryProvider));
});

final suspendShopMemberProvider = Provider<SuspendShopMember>((ref) {
  return SuspendShopMember(ref.read(shopMembersRepositoryProvider));
});

final restoreShopMemberProvider = Provider<RestoreShopMember>((ref) {
  return RestoreShopMember(ref.read(shopMembersRepositoryProvider));
});

final revokeShopMemberProvider = Provider<RevokeShopMember>((ref) {
  return RevokeShopMember(ref.read(shopMembersRepositoryProvider));
});

/// The members of the owner's shop, for Users & Permissions. Scoped to the
/// signed-in account like every other session-scoped provider. Whether the
/// account is the owner comes from `shopAccessProvider` (the router); the
/// database refuses the list to anyone else.
final shopMembersProvider = FutureProvider.autoDispose<List<ShopMember>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.read(getShopMembersProvider).call();
});
