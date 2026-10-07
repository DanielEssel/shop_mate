import '../entities/new_shop_attendant.dart';
import '../repositories/shop_members_repository.dart';

class CreateShopAttendant {
  CreateShopAttendant(this._repository);

  final ShopMembersRepository _repository;

  Future<CreatedShopAttendant> call(NewShopAttendant attendant) {
    return _repository.createAttendant(attendant);
  }
}
