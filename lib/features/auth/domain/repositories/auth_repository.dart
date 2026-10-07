import '../entities/auth_credentials.dart';
import '../entities/auth_user.dart';
import '../entities/sign_up_outcome.dart';

/// Email and password authentication. Every method throws an [AuthFailure]
/// (never a backend exception) when it fails.
abstract class AuthRepository {
  Future<AuthUser> signIn(AuthCredentials credentials);

  Future<SignUpOutcome> signUp(AuthCredentials credentials);

  /// Signs this device out. Succeeds once the local session is gone, even if
  /// the server could not be told.
  Future<void> signOut();

  /// Sends the sign-up confirmation email to [email] again.
  Future<void> resendEmailConfirmation(String email);

  /// Sends a password reset email with a one-time recovery code to [email].
  Future<void> requestPasswordReset(String email);

  /// Checks the recovery [code] sent to [email]. On success the account is
  /// signed in with a recovery session, which only lasts until the new
  /// password is set and the user is signed out again.
  Future<AuthUser> verifyPasswordResetCode({
    required String email,
    required String code,
  });

  /// Sets a new password for the signed-in (recovering) account.
  Future<void> updatePassword(String newPassword);

  /// The signed-in account, or null when signed out.
  AuthUser? get currentUser;

  /// Emits the signed-in account (or null) on every auth state change,
  /// starting with the restored session.
  Stream<AuthUser?> get authStateChanges;
}
