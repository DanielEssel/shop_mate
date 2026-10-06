import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/shop_branding_exception.dart';
import '../../domain/entities/shop_branding_result.dart';
import '../../domain/entities/shop_logo_upload.dart';
import '../../domain/entities/shop_profile_update.dart';
import '../../domain/repositories/shop_branding_repository.dart';
import '../datasources/shop_branding_remote_datasource.dart';

class ShopBrandingRepositoryImpl implements ShopBrandingRepository {
  ShopBrandingRepositoryImpl(this._remoteDataSource);

  final ShopBrandingRemoteDataSource _remoteDataSource;

  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) {
    return _load(shopId);
  }

  /// Order: upload new object -> set_shop_logo -> delete old object -> read.
  /// The shop always points at an object that exists, and a successful new
  /// logo is never rolled back because of a cleanup problem.
  @override
  Future<ShopBrandingResult> uploadLogo(
    String shopId,
    ShopLogoUpload upload,
  ) async {
    final String? previousPath;
    try {
      previousPath = (await _remoteDataSource.fetchBranding(shopId)).logoPath;
    } catch (error) {
      throw _translate(error, ShopBrandingErrorKind.uploadFailed);
    }

    final newPath = _remoteDataSource.newLogoPath(shopId, upload.extension);

    try {
      await _remoteDataSource.uploadLogoObject(newPath, upload);
    } catch (error) {
      throw _translate(error, ShopBrandingErrorKind.uploadFailed);
    }

    try {
      await _remoteDataSource.setShopLogo(newPath);
    } catch (error) {
      // The shop still points at its previous logo, which is kept. Remove
      // the orphaned upload on a best-effort basis.
      try {
        await _remoteDataSource.deleteLogoObjects([newPath]);
      } catch (cleanupError) {
        debugPrint('SHOP LOGO ORPHAN CLEANUP FAILED: $cleanupError');
      }
      throw _translate(error, ShopBrandingErrorKind.uploadFailed);
    }

    final cleanupError = previousPath == null || previousPath == newPath
        ? null
        : await _deleteQuietly(previousPath);

    return _load(shopId, cleanupError: cleanupError);
  }

  /// Order: clear_shop_logo -> delete the returned previous object -> read.
  /// A failed delete never restores the cleared logo.
  @override
  Future<ShopBrandingResult> removeLogo(String shopId) async {
    final String? previousPath;
    try {
      previousPath = await _remoteDataSource.clearShopLogo();
    } catch (error) {
      throw _translate(error, ShopBrandingErrorKind.removeFailed);
    }

    final cleanupError = previousPath == null
        ? null
        : await _deleteQuietly(previousPath);

    return _load(shopId, cleanupError: cleanupError);
  }

  @override
  Future<ShopBrandingResult> updateProfile(
    String shopId,
    ShopProfileUpdate update,
  ) async {
    try {
      await _remoteDataSource.updateShopProfile(
        name: update.name,
        phone: update.phone,
      );
    } catch (error) {
      throw _translate(error, ShopBrandingErrorKind.profileUpdateFailed);
    }

    return _load(shopId);
  }

  /// Reads the shop row, then the logo. A logo that fails to download is
  /// reported on the result instead of failing the whole read.
  Future<ShopBrandingResult> _load(
    String shopId, {
    ShopBrandingException? cleanupError,
  }) async {
    final ShopBrandingResult withoutLogo;
    try {
      final branding = await _remoteDataSource.fetchBranding(shopId);
      withoutLogo = ShopBrandingResult(
        branding: branding,
        cleanupError: cleanupError,
      );
    } catch (error) {
      throw _translate(error, ShopBrandingErrorKind.unavailable);
    }

    final logoPath = withoutLogo.branding.logoPath;
    if (logoPath == null) return withoutLogo;

    try {
      final bytes = await _remoteDataSource.downloadLogo(logoPath);
      return ShopBrandingResult(
        branding: withoutLogo.branding,
        logoBytes: bytes,
        cleanupError: cleanupError,
      );
    } catch (error) {
      debugPrint('SHOP LOGO DOWNLOAD FAILED: $error');
      return ShopBrandingResult(
        branding: withoutLogo.branding,
        logoError: ShopBrandingException(
          ShopBrandingErrorKind.logoUnavailable,
          cause: error,
        ),
        cleanupError: cleanupError,
      );
    }
  }

  Future<ShopBrandingException?> _deleteQuietly(String logoPath) async {
    try {
      await _remoteDataSource.deleteLogoObjects([logoPath]);
      return null;
    } catch (error) {
      debugPrint('SHOP LOGO CLEANUP FAILED for $logoPath: $error');
      return ShopBrandingException(
        ShopBrandingErrorKind.cleanupFailed,
        cause: error,
      );
    }
  }

  /// Maps backend errors to a user-safe kind; raw text stays in `cause`.
  ShopBrandingException _translate(
    Object error,
    ShopBrandingErrorKind fallback,
  ) {
    if (error is ShopBrandingException) return error;

    if (error is PostgrestException) {
      if (error.code == '42501' ||
          error.message.contains('Only the shop owner')) {
        return ShopBrandingException(
          ShopBrandingErrorKind.permissionDenied,
          cause: error,
        );
      }
      if (error.message.contains('Business name must be')) {
        return ShopBrandingException(
          ShopBrandingErrorKind.invalidName,
          cause: error,
        );
      }
      if (error.message.contains('Invalid phone number')) {
        return ShopBrandingException(
          ShopBrandingErrorKind.invalidPhone,
          cause: error,
        );
      }
    }

    if (error is StorageException) {
      final status = error.statusCode;
      if (status == '403' || error.message.contains('row-level security')) {
        return ShopBrandingException(
          ShopBrandingErrorKind.permissionDenied,
          cause: error,
        );
      }
      if (status == '413') {
        return ShopBrandingException(
          ShopBrandingErrorKind.tooLarge,
          cause: error,
        );
      }
      if (status == '415') {
        return ShopBrandingException(
          ShopBrandingErrorKind.invalidFormat,
          cause: error,
        );
      }
    }

    return ShopBrandingException(fallback, cause: error);
  }
}
