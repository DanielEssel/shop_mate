import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/new_shop_attendant.dart';
import '../../domain/entities/shop_member.dart';
import '../../domain/entities/shop_members_exception.dart';
import '../../domain/repositories/shop_members_repository.dart';
import '../datasources/shop_members_remote_datasource.dart';

class ShopMembersRepositoryImpl implements ShopMembersRepository {
  ShopMembersRepositoryImpl(this._remoteDataSource);

  final ShopMembersRemoteDataSource _remoteDataSource;

  @override
  Future<List<ShopMember>> getMembers() async {
    try {
      return await _remoteDataSource.getMembers();
    } catch (error) {
      throw _translateRpc(error, ShopMembersErrorKind.loadFailed);
    }
  }

  @override
  Future<CreatedShopAttendant> createAttendant(
    NewShopAttendant attendant,
  ) async {
    try {
      return await _remoteDataSource.createAttendant(attendant);
    } catch (error) {
      throw _translateFunction(error);
    }
  }

  @override
  Future<void> suspendMember(String memberUserId) => _act(
    () => _remoteDataSource.setMemberStatus(
      memberUserId,
      ShopMemberStatus.suspended,
    ),
  );

  @override
  Future<void> restoreMember(String memberUserId) => _act(
    () => _remoteDataSource.setMemberStatus(
      memberUserId,
      ShopMemberStatus.active,
    ),
  );

  @override
  Future<void> revokeMember(String memberUserId) =>
      _act(() => _remoteDataSource.removeMember(memberUserId));

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw _translateRpc(error, ShopMembersErrorKind.actionFailed);
    }
  }

  /// PostgREST rejects an expired or invalid session with these codes.
  static const _sessionCodes = {'PGRST301', 'PGRST302', 'PGRST303'};

  /// Maps the RPCs' SQLSTATEs to a user-safe kind; the database's own text
  /// is dropped.
  static ShopMembersException _translateRpc(
    Object error,
    ShopMembersErrorKind fallback,
  ) {
    if (error is ShopMembersException) return error;
    if (error is! PostgrestException) return ShopMembersException(fallback);

    final code = error.code;
    final kind = switch (code) {
      // Not signed in, not the active owner of an active shop, or the owner
      // targeting themselves or another owner.
      '42501' => ShopMembersErrorKind.permissionDenied,
      'P0002' => ShopMembersErrorKind.notFound,
      // Already suspended / already active.
      '55000' => ShopMembersErrorKind.statusChanged,
      final String c when _sessionCodes.contains(c) =>
        ShopMembersErrorKind.sessionExpired,
      _ => fallback,
    };
    return ShopMembersException(kind, code: code);
  }

  /// Maps the Edge Function's HTTP status and `error.code` to a user-safe
  /// kind; the response's own message text is dropped.
  static ShopMembersException _translateFunction(Object error) {
    if (error is ShopMembersException) return error;
    // No response at all: offline, DNS, timeout.
    if (error is FunctionsFetchException) {
      return const ShopMembersException(ShopMembersErrorKind.network);
    }
    if (error is! FunctionException) {
      return const ShopMembersException(ShopMembersErrorKind.createFailed);
    }

    final code = _functionErrorCode(error.details);
    final kind = switch (error.status) {
      401 => ShopMembersErrorKind.sessionExpired,
      403 => ShopMembersErrorKind.permissionDenied,
      409 => ShopMembersErrorKind.emailExists,
      400 => switch (code) {
        'invalid_email' => ShopMembersErrorKind.invalidEmail,
        'invalid_name' => ShopMembersErrorKind.invalidName,
        'invalid_password' ||
        'weak_password' => ShopMembersErrorKind.invalidPassword,
        _ => ShopMembersErrorKind.createFailed,
      },
      _ => ShopMembersErrorKind.createFailed,
    };
    return ShopMembersException(kind, code: code ?? '${error.status}');
  }

  /// `{"error": {"code": "..."}}` from the Edge Function, if present.
  static String? _functionErrorCode(Object? details) {
    if (details is! Map) return null;
    final Object? error = details['error'];
    if (error is! Map) return null;
    final Object? code = error['code'];
    return code is String ? code : null;
  }
}
