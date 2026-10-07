import '../repositories/admin_repository.dart';

class CheckPlatformAdmin {
  CheckPlatformAdmin(this._repository);

  final AdminRepository _repository;

  Future<bool> call() {
    return _repository.isPlatformAdmin();
  }
}
