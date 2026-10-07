import 'dart:async';

import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop_members/domain/entities/new_shop_attendant.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_member.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_members_exception.dart';
import 'package:shopmate/features/shop_members/domain/repositories/shop_members_repository.dart';

ShopMember shopMember(
  String userId, {
  ShopRole role = ShopRole.attendant,
  ShopMemberStatus status = ShopMemberStatus.active,
  String? displayName,
  String? email,
}) {
  return ShopMember(
    memberId: 'm-$userId',
    userId: userId,
    role: role,
    status: status,
    displayName: displayName,
    email: email ?? '$userId@shop.test',
    createdAt: DateTime.utc(2026, 10, 1, 9),
    updatedAt: DateTime.utc(2026, 10, 2),
  );
}

/// The signed-in owner in the screen tests.
const ownerUserId = 'owner-1';

final ownerMember = shopMember(
  ownerUserId,
  role: ShopRole.owner,
  displayName: 'Kwame Owner',
  email: 'kwame@shop.test',
);

/// In-memory stand-in that follows the backend contract: only attendants
/// can be changed, each status change only moves out of the status it
/// expects (otherwise statusChanged), and revoking removes the membership.
class FakeShopMembersRepository implements ShopMembersRepository {
  FakeShopMembersRepository({List<ShopMember>? members})
    : _members = [...?members];

  final List<ShopMember> _members;

  /// Every change requested, e.g. 'suspend staff-1'.
  final actions = <String>[];

  /// Every create request, as received.
  final created = <NewShopAttendant>[];

  int loads = 0;

  /// The next [getMembers] fails with this, once.
  ShopMembersException? loadError;

  /// While set, [getMembers] waits for it (to show the loading state).
  Completer<void>? loadGate;

  /// The next [createAttendant] fails with this, once.
  ShopMembersException? createError;

  /// While set, [createAttendant] waits for it (to show the submitting
  /// state).
  Completer<void>? createGate;

  bool confirmationEmailSent = true;

  /// The next change fails with this, once.
  ShopMembersException? actionError;

  List<ShopMember> get members => List.unmodifiable(_members);

  @override
  Future<List<ShopMember>> getMembers() async {
    loads++;
    await loadGate?.future;
    final error = loadError;
    if (error != null) {
      loadError = null;
      throw error;
    }
    return List.of(_members);
  }

  @override
  Future<CreatedShopAttendant> createAttendant(
    NewShopAttendant attendant,
  ) async {
    created.add(attendant);
    await createGate?.future;
    final error = createError;
    if (error != null) {
      createError = null;
      throw error;
    }
    final userId = 'new-${created.length}';
    _members.add(
      shopMember(
        userId,
        displayName: attendant.displayName,
        email: attendant.email,
      ),
    );
    return CreatedShopAttendant(
      userId: userId,
      email: attendant.email,
      displayName: attendant.displayName,
      confirmationEmailSent: confirmationEmailSent,
    );
  }

  @override
  Future<void> suspendMember(String memberUserId) =>
      _setStatus('suspend', memberUserId, ShopMemberStatus.suspended);

  @override
  Future<void> restoreMember(String memberUserId) =>
      _setStatus('restore', memberUserId, ShopMemberStatus.active);

  @override
  Future<void> revokeMember(String memberUserId) async {
    actions.add('revoke $memberUserId');
    _throwPendingError();
    final index = _attendantIndex(memberUserId);
    _members.removeAt(index);
  }

  Future<void> _setStatus(
    String name,
    String memberUserId,
    ShopMemberStatus status,
  ) async {
    actions.add('$name $memberUserId');
    _throwPendingError();
    final index = _attendantIndex(memberUserId);
    final member = _members[index];
    if (member.status == status) {
      throw const ShopMembersException(ShopMembersErrorKind.statusChanged);
    }
    _members[index] = ShopMember(
      memberId: member.memberId,
      userId: member.userId,
      role: member.role,
      status: status,
      email: member.email,
      displayName: member.displayName,
      createdAt: member.createdAt,
      updatedAt: DateTime.utc(2026, 10, 3),
    );
  }

  void _throwPendingError() {
    final error = actionError;
    if (error != null) {
      actionError = null;
      throw error;
    }
  }

  int _attendantIndex(String memberUserId) {
    final index = _members.indexWhere((m) => m.userId == memberUserId);
    if (index < 0) {
      throw const ShopMembersException(ShopMembersErrorKind.notFound);
    }
    if (_members[index].isOwner) {
      throw const ShopMembersException(ShopMembersErrorKind.permissionDenied);
    }
    return index;
  }
}
