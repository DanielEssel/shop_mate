import 'package:flutter/foundation.dart';

import 'product_category_exception.dart';

/// A validated category name: trimmed, 1 to 60 characters (counted like
/// Postgres `char_length`). Case-insensitive uniqueness among active
/// categories is enforced by the database.
@immutable
class ProductCategoryName {
  const ProductCategoryName._(this.value);

  factory ProductCategoryName(String input) {
    final trimmed = input.trim();
    if (!isValid(trimmed)) {
      throw const ProductCategoryException(
        ProductCategoryErrorKind.invalidName,
      );
    }
    return ProductCategoryName._(trimmed);
  }

  static const maxLength = 60;

  static bool isValid(String input) {
    final length = input.trim().runes.length;
    return length >= 1 && length <= maxLength;
  }

  final String value;
}
