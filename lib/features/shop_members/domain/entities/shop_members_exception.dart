/// Why a shop member operation failed.
enum ShopMembersErrorKind {
  permissionDenied("You don't have permission to manage shop users."),
  sessionExpired('Your session has expired. Please sign in again.'),
  network(
    "We couldn't reach ShopMate. Check your internet connection and try "
    'again.',
  ),
  emailExists(
    'This email already has a ShopMate account. Use another email address.',
  ),
  invalidEmail('Enter a valid email address.'),
  invalidName('Enter a name of 1 to 80 characters.'),
  invalidPassword(
    'Choose a stronger temporary password of 8 to 72 characters that is not '
    'the email address.',
  ),
  createFailed(
    'Something went wrong while creating the attendant. Please try again.',
  ),
  notFound(
    'This attendant is no longer a member of your shop. The list has been '
    'refreshed.',
  ),
  statusChanged(
    "This attendant's access has already changed. The list has been "
    'refreshed.',
  ),
  loadFailed(
    'Shop users could not be loaded. Check your connection and try again.',
  ),
  actionFailed(
    "We couldn't update this attendant's access. Check your connection and "
    'try again.',
  );

  const ShopMembersErrorKind(this.message);

  /// Short message safe to show to the user.
  final String message;
}

/// A shop member failure with a user-safe [message]. Only the backend error
/// code is kept, for diagnostics; never the backend's message text.
class ShopMembersException implements Exception {
  const ShopMembersException(this.kind, {this.code});

  final ShopMembersErrorKind kind;
  final String? code;

  String get message => kind.message;

  @override
  String toString() => 'ShopMembersException(${kind.name}, code: $code)';
}
