import '../repositories/shop_members_repository.dart';

class SuspendShopMember {
  SuspendShopMember(this._repository);

  final ShopMembersRepository _repository;

  Future<void> call(String memberUserId) {
    return _repository.suspendMember(memberUserId);
  }
}
