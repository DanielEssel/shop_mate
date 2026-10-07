import '../repositories/auth_repository.dart';

class RequestPasswordReset {
  RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email) {
    return _repository.requestPasswordReset(email.trim());
  }
}
