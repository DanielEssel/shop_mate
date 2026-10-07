import '../entities/auth_credentials.dart';
import '../entities/sign_up_outcome.dart';
import '../repositories/auth_repository.dart';

class SignUp {
  SignUp(this._repository);

  final AuthRepository _repository;

  Future<SignUpOutcome> call(AuthCredentials credentials) {
    return _repository.signUp(credentials);
  }
}
