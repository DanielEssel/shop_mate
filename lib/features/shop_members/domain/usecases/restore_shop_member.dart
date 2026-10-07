import '../repositories/shop_members_repository.dart';

class RestoreShopMember {
  RestoreShopMember(this._repository);

  final ShopMembersRepository _repository;

  Future<void> call(String memberUserId) {
    return _repository.restoreMember(memberUserId);
  }
}
