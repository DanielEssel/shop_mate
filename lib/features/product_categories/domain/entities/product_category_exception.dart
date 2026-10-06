/// Why a product category operation failed.
enum ProductCategoryErrorKind {
  invalidName('Category name must be 1 to 60 characters.'),
  duplicateName('An active category with this name already exists.'),
  permissionDenied('Only the shop owner can manage categories.'),
  archived('This category is archived. Choose an active category.'),
  loadFailed('Categories could not be loaded. Please try again.'),
  saveFailed("We couldn't save the category. Please try again.");

  const ProductCategoryErrorKind(this.message);

  /// Short message safe to show to the user.
  final String message;
}

/// A category failure with a user-safe [message]; the backend error is kept
/// in [cause] for logging only.
class ProductCategoryException implements Exception {
  const ProductCategoryException(this.kind, {this.cause});

  final ProductCategoryErrorKind kind;
  final Object? cause;

  String get message => kind.message;

  @override
  String toString() => 'ProductCategoryException(${kind.name})';
}
