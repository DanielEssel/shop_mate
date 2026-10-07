import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../domain/entities/admin_shop.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/approve_shop.dart';
import '../../domain/usecases/check_platform_admin.dart';
import '../../domain/usecases/get_admin_shops.dart';
import '../../domain/usecases/reactivate_shop.dart';
import '../../domain/usecases/suspend_shop.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(
    AdminRemoteDataSource(ref.read(supabaseClientProvider)),
  );
});

final checkPlatformAdminProvider = Provider<CheckPlatformAdmin>((ref) {
  return CheckPlatformAdmin(ref.read(adminRepositoryProvider));
});

final getAdminShopsProvider = Provider<GetAdminShops>((ref) {
  return GetAdminShops(ref.read(adminRepositoryProvider));
});

final approveShopProvider = Provider<ApproveShop>((ref) {
  return ApproveShop(ref.read(adminRepositoryProvider));
});

final suspendShopProvider = Provider<SuspendShop>((ref) {
  return SuspendShop(ref.read(adminRepositoryProvider));
});

final reactivateShopProvider = Provider<ReactivateShop>((ref) {
  return ReactivateShop(ref.read(adminRepositoryProvider));
});

/// Whether the signed-in account is a ShopMate platform admin, as answered
/// by the database. Only decides what the UI offers; every admin RPC checks
/// again on the server.
///
/// Fails closed: signed out, an error, or a database without the admin
/// migration all mean "not an admin". Re-checked when the account changes.
final isPlatformAdminProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  try {
    return await ref.read(checkPlatformAdminProvider).call();
  } catch (_) {
    return false;
  }
});

/// Whether the admin UI may be shown right now: a settled `true` for the
/// current account (never a value kept from a previous account while the
/// check reloads).
extension PlatformAdminAccess on AsyncValue<bool> {
  bool get isConfirmedAdmin => !isLoading && unwrapPrevious().value == true;
}

/// Shops in one status, for the admin screen. Scoped to the signed-in
/// account like every other session-scoped provider.
final adminShopsProvider = FutureProvider.autoDispose
    .family<List<AdminShop>, AdminShopStatus>((ref, status) {
      ref.watch(currentUserIdProvider);
      return ref.read(getAdminShopsProvider).call(status);
    });
