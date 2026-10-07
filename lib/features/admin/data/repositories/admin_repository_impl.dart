import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/admin_exception.dart';
import '../../domain/entities/admin_shop.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._remoteDataSource);

  final AdminRemoteDataSource _remoteDataSource;

  @override
  Future<bool> isPlatformAdmin() async {
    try {
      return await _remoteDataSource.isPlatformAdmin();
    } catch (error) {
      throw _translate(error, AdminErrorKind.loadFailed);
    }
  }

  @override
  Future<List<AdminShop>> getShops(AdminShopStatus status) async {
    try {
      return await _remoteDataSource.getShops(status);
    } catch (error) {
      throw _translate(error, AdminErrorKind.loadFailed);
    }
  }

  @override
  Future<void> approveShop(String shopId) =>
      _act(() => _remoteDataSource.approveShop(shopId));

  @override
  Future<void> suspendShop(String shopId) =>
      _act(() => _remoteDataSource.suspendShop(shopId));

  @override
  Future<void> reactivateShop(String shopId) =>
      _act(() => _remoteDataSource.reactivateShop(shopId));

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw _translate(error, AdminErrorKind.actionFailed);
    }
  }

  /// Maps the RPCs' SQLSTATEs to a user-safe kind; the database's own text
  /// is dropped.
  static AdminException _translate(Object error, AdminErrorKind fallback) {
    if (error is AdminException) return error;
    if (error is! PostgrestException) return AdminException(fallback);

    final code = error.code;
    final kind = switch (code) {
      // Raised by every admin RPC for a caller who isn't a platform admin.
      '42501' => AdminErrorKind.permissionDenied,
      'P0002' => AdminErrorKind.notFound,
      // The shop is no longer in the state this action expects.
      '55000' => AdminErrorKind.statusChanged,
      _ => fallback,
    };
    return AdminException(kind, code: code);
  }
}
