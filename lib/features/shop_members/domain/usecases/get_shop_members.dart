import '../entities/shop_member.dart';
import '../repositories/shop_members_repository.dart';

class GetShopMembers {
  GetShopMembers(this._repository);

  final ShopMembersRepository _repository;

  Future<List<ShopMember>> call() {
    return _repository.getMembers();
  }
}
