import '../repositories/shop_members_repository.dart';

class RevokeShopMember {
  RevokeShopMember(this._repository);

  final ShopMembersRepository _repository;

  Future<void> call(String memberUserId) {
    return _repository.revokeMember(memberUserId);
  }
}
