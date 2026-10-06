/// Why a shop branding operation failed.
enum ShopBrandingErrorKind {
  unavailable('Shop branding could not be loaded.'),
  logoUnavailable('The shop logo could not be loaded.'),
  uploadFailed('The logo could not be uploaded. Please try again.'),
  removeFailed('The logo could not be removed. Please try again.'),
  invalidFormat('Choose a PNG or JPEG image.'),
  tooLarge('The logo must be 1 MB or smaller.'),
  emptyFile('The selected image is empty.'),
  permissionDenied('Only the shop owner can change the shop logo.'),
  cleanupFailed(
    'The logo was updated, but the previous image could not be deleted.',
  ),
  invalidName('Business name must be 2 to 80 characters.'),
  invalidPhone('Enter a valid phone number.'),
  profileUpdateFailed(
    'The business profile could not be saved. Please try again.',
  );

  const ShopBrandingErrorKind(this.message);

  /// Short message safe to show to the user.
  final String message;
}

/// A shop branding failure with a user-safe [message]. The underlying error
/// is kept in [cause] for logging only.
class ShopBrandingException implements Exception {
  const ShopBrandingException(this.kind, {this.cause});

  final ShopBrandingErrorKind kind;
  final Object? cause;

  String get message => kind.message;

  @override
  String toString() => 'ShopBrandingException(${kind.name})';
}
