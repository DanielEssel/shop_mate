/// Why an authentication request failed.
enum AuthFailureKind {
  invalidCredentials('Incorrect email or password.'),
  emailNotConfirmed('Please confirm your email before signing in.'),
  emailAlreadyRegistered(
    'An account with this email already exists. Please sign in instead.',
  ),
  weakPassword('Please choose a stronger password.'),
  invalidEmail('Enter a valid email address.'),
  tooManyRequests('Too many attempts. Please wait a moment and try again.'),
  network(
    "We couldn't reach ShopMate. Check your internet connection and try "
    'again.',
  ),
  sessionExpired('Your session has expired. Please sign in again.'),
  invalidRecoveryCode(
    'That code is invalid or has expired. Check your latest email or send a '
    'new code.',
  ),
  samePassword('Choose a password different from your current one.'),
  unknown('Something went wrong. Please try again.');

  const AuthFailureKind(this.message);

  /// Short message safe to show to the user.
  final String message;
}

/// An authentication failure with a user-safe [message]. The backend's own
/// error text is never carried; [code] keeps its error code (for example
/// `invalid_credentials`) for diagnostics only.
class AuthFailure implements Exception {
  const AuthFailure(this.kind, {this.code});

  final AuthFailureKind kind;
  final String? code;

  String get message => kind.message;

  @override
  String toString() => 'AuthFailure(${kind.name}, code: $code)';
}
