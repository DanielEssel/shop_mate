import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/shop_branding_remote_datasource.dart';
import '../../data/repositories/shop_branding_repository_impl.dart';
import '../../domain/entities/shop_access.dart';
import '../../domain/entities/shop_branding_result.dart';
import '../../domain/entities/shop_logo_upload.dart';
import '../../domain/repositories/shop_branding_repository.dart';
import '../../domain/usecases/get_shop_branding.dart';
import '../../domain/usecases/remove_shop_logo.dart';
import '../../domain/usecases/upload_shop_logo.dart';
import 'shop_provider.dart';

final shopBrandingRepositoryProvider = Provider<ShopBrandingRepository>((ref) {
  return ShopBrandingRepositoryImpl(
    ShopBrandingRemoteDataSource(ref.read(supabaseClientProvider)),
  );
});

final getShopBrandingProvider = Provider<GetShopBranding>((ref) {
  return GetShopBranding(ref.read(shopBrandingRepositoryProvider));
});

final uploadShopLogoProvider = Provider<UploadShopLogo>((ref) {
  return UploadShopLogo(ref.read(shopBrandingRepositoryProvider));
});

final removeShopLogoProvider = Provider<RemoveShopLogo>((ref) {
  return RemoveShopLogo(ref.read(shopBrandingRepositoryProvider));
});

/// The active shop's id, or null when there is no active shop.
final _activeShopIdProvider = Provider<String?>((ref) {
  return ref.watch(
    shopAccessProvider.select((access) {
      final value = access.value;
      return value != null && value.status == ShopAccessStatus.active
          ? value.shopId
          : null;
    }),
  );
});

/// Branding for the current active shop, shared app-wide and kept in memory
/// for the session. Null when there is no active shop. Reloads when the
/// active shop changes (sign-in, sign-out, switching accounts).
///
/// A logo that fails to download still yields branding (see
/// [ShopBrandingResult.logoError]); only an unreadable shop row is an error.
final shopBrandingProvider =
    AsyncNotifierProvider<ShopBrandingNotifier, ShopBrandingResult?>(
      ShopBrandingNotifier.new,
    );

class ShopBrandingNotifier extends AsyncNotifier<ShopBrandingResult?> {
  @override
  Future<ShopBrandingResult?> build() async {
    final shopId = ref.watch(_activeShopIdProvider);
    if (shopId == null) return null;

    return ref.read(getShopBrandingProvider).call(shopId);
  }

  /// Uploads a new logo for the current shop and publishes the refreshed
  /// branding. Throws `ShopBrandingException` on failure.
  Future<ShopBrandingResult> uploadLogo(ShopLogoUpload upload) {
    return _mutate(
      (shopId) => ref.read(uploadShopLogoProvider).call(shopId, upload),
    );
  }

  /// Removes the current shop's logo and publishes the refreshed branding.
  /// Throws `ShopBrandingException` on failure.
  Future<ShopBrandingResult> removeLogo() {
    return _mutate((shopId) => ref.read(removeShopLogoProvider).call(shopId));
  }

  Future<ShopBrandingResult> _mutate(
    Future<ShopBrandingResult> Function(String shopId) operation,
  ) async {
    final shopId = ref.read(_activeShopIdProvider);
    if (shopId == null) {
      throw StateError('No active shop to update.');
    }

    try {
      final result = await operation(shopId);
      state = AsyncData(result);
      return result;
    } catch (_) {
      // The backend may have changed part-way; reload from the source.
      ref.invalidateSelf();
      rethrow;
    }
  }
}
