import '../entities/auth_credentials.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  SignIn(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call(AuthCredentials credentials) {
    return _repository.signIn(credentials);
  }
}
