import '../repositories/auth_repository.dart';

class UpdatePassword {
  UpdatePassword(this._repository);

  final AuthRepository _repository;

  /// The password is passed on exactly as typed.
  Future<void> call(String newPassword) {
    return _repository.updatePassword(newPassword);
  }
}
