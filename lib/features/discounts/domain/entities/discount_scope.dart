/// Which products a shop discount covers (`shop_discount_settings.scope`).
enum DiscountScope {
  allProducts('all_products'),
  selectedProducts('selected_products');

  const DiscountScope(this.value);

  /// The value stored in the database.
  final String value;

  static DiscountScope? fromValue(String value) {
    for (final scope in values) {
      if (scope.value == value) return scope;
    }
    return null;
  }
}
