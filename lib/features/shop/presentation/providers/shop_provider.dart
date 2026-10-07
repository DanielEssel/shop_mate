import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/shop_repository_impl.dart';
import '../../domain/entities/shop_access.dart';
import '../../domain/repositories/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepositoryImpl(
    ref.read(supabaseClientProvider),
  );
});

/// What the current account may access.
///
/// Rebuilds only when the signed-in USER changes (sign in / sign out /
/// switching accounts), not on hourly token refreshes. Call
/// `ref.invalidate(shopAccessProvider)` to re-check, e.g. after the user
/// registers a shop or taps "Check status".
///
/// It never throws: a failure becomes [ShopAccessStatus.unavailable], so the
/// router can show a retry screen instead of an endless spinner.
final shopAccessProvider = FutureProvider<ShopAccess>((ref) async {
  final userId = ref.watch(currentUserIdProvider);

  // Signed out. The router never reads this in that case, but the provider
  // must still return something.
  if (userId == null) {
    return const ShopAccess(
      userId: null,
      status: ShopAccessStatus.noShop,
    );
  }

  try {
    return await ref.read(shopRepositoryProvider).fetchAccess(userId);
  } catch (error) {
    debugPrint('SHOP ACCESS ERROR: $error');

    return ShopAccess(
      userId: userId,
      status: ShopAccessStatus.unavailable,
    );
  }
});

/// Selector for `ref.watch(shopAccessProvider.select(selectIsShopOwner))`:
/// true only for the owner of an active shop. Loading, errors, gate states
/// and every non-owner role are false, so owner-only UI fails closed.
///
/// This reads the one source of the role ([shopAccessProvider]); it is UI
/// only, and the database enforces every owner-only operation itself.
bool selectIsShopOwner(AsyncValue<ShopAccess> access) {
  final value = access.value;
  return value != null &&
      value.status == ShopAccessStatus.active &&
      value.isOwner;
}
