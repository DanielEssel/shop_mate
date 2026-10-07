import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/request_password_reset.dart';
import '../../domain/usecases/resend_email_confirmation.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/update_password.dart';
import '../../domain/usecases/verify_password_reset_code.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(supabaseClientProvider).auth);
});

final signInProvider = Provider<SignIn>((ref) {
  return SignIn(ref.read(authRepositoryProvider));
});

final signUpProvider = Provider<SignUp>((ref) {
  return SignUp(ref.read(authRepositoryProvider));
});

final signOutProvider = Provider<SignOut>((ref) {
  return SignOut(ref.read(authRepositoryProvider));
});

final resendEmailConfirmationProvider = Provider<ResendEmailConfirmation>((
  ref,
) {
  return ResendEmailConfirmation(ref.read(authRepositoryProvider));
});

final requestPasswordResetProvider = Provider<RequestPasswordReset>((ref) {
  return RequestPasswordReset(ref.read(authRepositoryProvider));
});

final verifyPasswordResetCodeProvider = Provider<VerifyPasswordResetCode>((
  ref,
) {
  return VerifyPasswordResetCode(ref.read(authRepositoryProvider));
});

final updatePasswordProvider = Provider<UpdatePassword>((ref) {
  return UpdatePassword(ref.read(authRepositoryProvider));
});

/// The signed-in account, or null when signed out. This is the app's single
/// source of authentication identity.
///
/// It starts from the session restored at startup (so the first frame already
/// knows who is signed in) and follows every auth state change after that.
final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthUser?>(
  AuthSessionNotifier.new,
);

class AuthSessionNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final repository = ref.watch(authRepositoryProvider);

    // Each event only triggers a re-read: the repository's current user is
    // always the latest, so a late or out-of-order event can't restore an
    // older account. Token refreshes keep the same value, and Riverpod drops
    // updates that are `==` to the previous state.
    final subscription = repository.authStateChanges.listen((_) {
      state = repository.currentUser;
    });
    ref.onDispose(subscription.cancel);

    return repository.currentUser;
  }

  /// The app's one sign-out path. The identity is cleared as soon as the
  /// local session is gone, without waiting for the auth event, so every
  /// session-scoped provider resets and the router moves to Login.
  Future<void> signOut() async {
    try {
      await ref.read(signOutProvider).call();
    } finally {
      state = ref.read(authRepositoryProvider).currentUser;
    }
  }
}

/// The signed-in user's id: the session boundary for cached data.
///
/// Every provider that holds user or shop data watches this, so a change of
/// account (A -> signed out -> B) throws away everything A loaded. It changes
/// only when the account changes, never on token refreshes.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authSessionProvider.select((user) => user?.id));
});
