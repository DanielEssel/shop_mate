import '../entities/product_category.dart';
import '../entities/product_category_name.dart';
import '../entities/product_category_summary.dart';

/// Categories of the caller's current shop. Row-level security limits every
/// read and write to that shop; only the owner can create or change
/// categories. Failures are thrown as `ProductCategoryException`.
abstract class ProductCategoryRepository {
  /// Every category (active and archived), ordered by name, with active
  /// product counts.
  Future<List<ProductCategorySummary>> getCategories();

  /// Active categories only, ordered by name, for product forms and filters.
  Future<List<ProductCategory>> getActiveCategories();

  Future<ProductCategory> createCategory(ProductCategoryName name);

  Future<ProductCategory> renameCategory(String id, ProductCategoryName name);

  /// Archives ([isActive] false) or restores ([isActive] true) a category.
  Future<ProductCategory> setCategoryActive(
    String id, {
    required bool isActive,
  });
}
