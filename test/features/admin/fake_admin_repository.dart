import 'dart:async';

import 'package:shopmate/features/admin/domain/entities/admin_exception.dart';
import 'package:shopmate/features/admin/domain/entities/admin_shop.dart';
import 'package:shopmate/features/admin/domain/repositories/admin_repository.dart';

AdminShop adminShop(
  String id,
  String name,
  AdminShopStatus status, {
  String? ownerEmail = 'owner@shop.test',
  String? phone = '+233241234567',
  DateTime? approvedAt,
}) {
  return AdminShop(
    id: id,
    name: name,
    status: status,
    phone: phone,
    ownerEmail: ownerEmail,
    createdAt: DateTime.utc(2026, 10, 1, 9),
    approvedAt:
        approvedAt ??
        (status == AdminShopStatus.pending ? null : DateTime.utc(2026, 10, 2)),
    updatedAt: DateTime.utc(2026, 10, 2),
  );
}

/// In-memory stand-in that follows the database contract: non-admins get
/// permissionDenied, and each action only moves a shop out of the status it
/// expects (otherwise statusChanged).
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({
    this.isAdmin = false,
    List<AdminShop> shops = const [],
    this.currentUserId,
    this.adminUserIds = const {},
  }) : _shops = [...shops];

  /// Used when [currentUserId] is not set.
  bool isAdmin;

  /// When set, the caller is an admin only if its id is in [adminUserIds],
  /// like `is_platform_admin()` keyed on `auth.uid()`.
  final String? Function()? currentUserId;
  final Set<String> adminUserIds;

  bool get _callerIsAdmin {
    final lookup = currentUserId;
    if (lookup == null) return isAdmin;
    return adminUserIds.contains(lookup());
  }

  final List<AdminShop> _shops;

  /// When set, every load fails with it.
  AdminException? loadFailure;

  /// When set, the next action fails with it.
  AdminException? actionFailure;

  /// When set, actions wait for it (to observe the in-progress state).
  Completer<void>? actionGate;

  /// When set, loads wait for it.
  Completer<void>? loadGate;

  final actions = <String>[];
  int adminChecks = 0;

  List<AdminShop> shopsIn(AdminShopStatus status) =>
      _shops.where((shop) => shop.status == status).toList();

  @override
  Future<bool> isPlatformAdmin() async {
    adminChecks++;
    return _callerIsAdmin;
  }

  @override
  Future<List<AdminShop>> getShops(AdminShopStatus status) async {
    await loadGate?.future;
    _requireAdmin();
    final failure = loadFailure;
    if (failure != null) throw failure;
    return shopsIn(status);
  }

  @override
  Future<void> approveShop(String shopId) =>
      _move('approve', shopId, AdminShopStatus.pending, AdminShopStatus.active);

  @override
  Future<void> suspendShop(String shopId) => _move(
    'suspend',
    shopId,
    AdminShopStatus.active,
    AdminShopStatus.suspended,
  );

  @override
  Future<void> reactivateShop(String shopId) => _move(
    'reactivate',
    shopId,
    AdminShopStatus.suspended,
    AdminShopStatus.active,
  );

  Future<void> _move(
    String action,
    String shopId,
    AdminShopStatus from,
    AdminShopStatus to,
  ) async {
    actions.add('$action $shopId');
    await actionGate?.future;
    _requireAdmin();
    final failure = actionFailure;
    if (failure != null) {
      actionFailure = null;
      throw failure;
    }

    final index = _shops.indexWhere((shop) => shop.id == shopId);
    if (index == -1) {
      throw const AdminException(AdminErrorKind.notFound, code: 'P0002');
    }
    final shop = _shops[index];
    if (shop.status != from) {
      throw const AdminException(AdminErrorKind.statusChanged, code: '55000');
    }
    _shops[index] = AdminShop(
      id: shop.id,
      name: shop.name,
      status: to,
      phone: shop.phone,
      ownerEmail: shop.ownerEmail,
      createdAt: shop.createdAt,
      approvedAt: shop.approvedAt ?? DateTime.utc(2026, 10, 7),
      updatedAt: DateTime.utc(2026, 10, 7),
    );
  }

  void _requireAdmin() {
    if (!_callerIsAdmin) {
      throw const AdminException(
        AdminErrorKind.permissionDenied,
        code: '42501',
      );
    }
  }
}
