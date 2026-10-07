import '../repositories/auth_repository.dart';

class ResendEmailConfirmation {
  ResendEmailConfirmation(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email) {
    return _repository.resendEmailConfirmation(email.trim());
  }
}
