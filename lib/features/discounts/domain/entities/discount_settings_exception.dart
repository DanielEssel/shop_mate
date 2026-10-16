/// Why a discount settings operation failed.
enum DiscountSettingsErrorKind {
  /// This app build does not save discount settings yet (release gate).
  writesNotAvailable(
    "Discount activation isn't available yet. Your changes were not saved. "
    'Saving will be switched on in a coming ShopMate update.',
  ),

  /// The database refused the write (not the owner, or writes not yet
  /// permitted for the shop).
  permissionDenied(
    "Discount settings can't be changed for this shop yet. Your changes "
    'were not saved.',
  ),
  network(
    "We couldn't reach ShopMate. Check your internet connection and try "
    'again. Your changes were not saved.',
  ),
  invalid(
    'The discount settings were not accepted. Check the percentage and end '
    'date, then try again.',
  ),
  unsafeSelection(
    'Some selected products would sell below their cost. Remove or reprice '
    'them before saving.',
  ),
  noProductsSelected('Select at least one product for this discount.'),
  endDateInPast('Choose an end date in the future, or remove it.'),
  loadFailed(
    'Discount settings could not be loaded. Check your connection and try '
    'again.',
  ),
  saveFailed("We couldn't save the discount settings. Please try again.");

  const DiscountSettingsErrorKind(this.message);

  /// Short message safe to show to the user.
  final String message;
}

/// A discount settings failure with a user-safe [message]. Only the backend
/// error code is kept, for diagnostics; never the backend's message text.
class DiscountSettingsException implements Exception {
  const DiscountSettingsException(this.kind, {this.code});

  final DiscountSettingsErrorKind kind;
  final String? code;

  String get message => kind.message;

  @override
  String toString() => 'DiscountSettingsException(${kind.name}, code: $code)';
}
