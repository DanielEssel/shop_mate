import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_category_exception.dart';
import '../../domain/entities/product_category_name.dart';
import '../../domain/entities/product_category_summary.dart';
import '../../domain/repositories/product_category_repository.dart';
import '../datasources/product_category_remote_datasource.dart';

class ProductCategoryRepositoryImpl implements ProductCategoryRepository {
  ProductCategoryRepositoryImpl(this._remoteDataSource);

  final ProductCategoryRemoteDataSource _remoteDataSource;

  /// Unique index for active category names per shop.
  static const _activeNameIndex = 'product_categories_shop_active_name_uidx';

  @override
  Future<List<ProductCategorySummary>> getCategories() async {
    try {
      final categories = await _remoteDataSource.getCategories(
        activeOnly: false,
      );
      final counts = await _remoteDataSource.getActiveProductCounts();
      return categories
          .map(
            (category) => ProductCategorySummary(
              category: category,
              activeProductCount: counts[category.id] ?? 0,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw _translate(error, ProductCategoryErrorKind.loadFailed);
    }
  }

  @override
  Future<List<ProductCategory>> getActiveCategories() async {
    try {
      return await _remoteDataSource.getCategories(activeOnly: true);
    } catch (error) {
      throw _translate(error, ProductCategoryErrorKind.loadFailed);
    }
  }

  @override
  Future<ProductCategory> createCategory(ProductCategoryName name) async {
    try {
      return await _remoteDataSource.createCategory(name.value);
    } catch (error) {
      throw _translate(error, ProductCategoryErrorKind.saveFailed);
    }
  }

  @override
  Future<ProductCategory> renameCategory(
    String id,
    ProductCategoryName name,
  ) async {
    try {
      return await _remoteDataSource.updateCategory(id, name: name.value);
    } catch (error) {
      throw _translate(error, ProductCategoryErrorKind.saveFailed);
    }
  }

  @override
  Future<ProductCategory> setCategoryActive(
    String id, {
    required bool isActive,
  }) async {
    try {
      return await _remoteDataSource.updateCategory(id, isActive: isActive);
    } catch (error) {
      throw _translate(error, ProductCategoryErrorKind.saveFailed);
    }
  }

  /// Maps database errors to a user-safe kind; raw text stays in `cause`.
  ProductCategoryException _translate(
    Object error,
    ProductCategoryErrorKind fallback,
  ) {
    if (error is ProductCategoryException) return error;

    if (error is PostgrestException) {
      final details = '${error.message} ${error.details ?? ''}';
      if (error.code == '23505' && details.contains(_activeNameIndex)) {
        return ProductCategoryException(
          ProductCategoryErrorKind.duplicateName,
          cause: error,
        );
      }
      if (error.code == '23514') {
        return ProductCategoryException(
          ProductCategoryErrorKind.invalidName,
          cause: error,
        );
      }
      // RLS rejects writes from non-owners; an update hidden by RLS returns
      // no row (PGRST116).
      if (error.code == '42501' ||
          error.code == 'PGRST116' ||
          error.message.contains('row-level security')) {
        return ProductCategoryException(
          ProductCategoryErrorKind.permissionDenied,
          cause: error,
        );
      }
    }

    return ProductCategoryException(fallback, cause: error);
  }
}
