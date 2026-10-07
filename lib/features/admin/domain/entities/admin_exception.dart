/// Why a platform admin operation failed.
enum AdminErrorKind {
  permissionDenied('Only ShopMate platform admins can do this.'),
  notFound('This shop no longer exists.'),
  statusChanged(
    "This shop's status has already changed. The list has been refreshed.",
  ),
  loadFailed('Shops could not be loaded. Please try again.'),
  actionFailed("We couldn't update the shop. Please try again.");

  const AdminErrorKind(this.message);

  /// Short message safe to show to the user.
  final String message;
}

/// An admin failure with a user-safe [message]. Only the backend error code
/// is kept, for diagnostics; never the backend's message text.
class AdminException implements Exception {
  const AdminException(this.kind, {this.code});

  final AdminErrorKind kind;
  final String? code;

  String get message => kind.message;

  @override
  String toString() => 'AdminException(${kind.name}, code: $code)';
}
