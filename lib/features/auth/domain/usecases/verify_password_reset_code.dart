import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class VerifyPasswordResetCode {
  VerifyPasswordResetCode(this._repository);

  final AuthRepository _repository;

  /// Spaces are dropped from [code] (it is often pasted as "123 456").
  Future<AuthUser> call({required String email, required String code}) {
    return _repository.verifyPasswordResetCode(
      email: email.trim(),
      code: code.replaceAll(RegExp(r'\s'), ''),
    );
  }
}
