import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../data/datasources/product_category_remote_datasource.dart';
import '../../data/repositories/product_category_repository_impl.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_category_summary.dart';
import '../../domain/repositories/product_category_repository.dart';
import '../../domain/usecases/create_product_category.dart';
import '../../domain/usecases/get_active_product_categories.dart';
import '../../domain/usecases/get_product_categories.dart';
import '../../domain/usecases/rename_product_category.dart';
import '../../domain/usecases/set_product_category_active.dart';

final productCategoryRepositoryProvider = Provider<ProductCategoryRepository>((
  ref,
) {
  return ProductCategoryRepositoryImpl(
    ProductCategoryRemoteDataSource(SupabaseService.client),
  );
});

final getProductCategoriesProvider = Provider<GetProductCategories>((ref) {
  return GetProductCategories(ref.read(productCategoryRepositoryProvider));
});

final getActiveProductCategoriesProvider = Provider<GetActiveProductCategories>(
  (ref) {
    return GetActiveProductCategories(
      ref.read(productCategoryRepositoryProvider),
    );
  },
);

final createProductCategoryProvider = Provider<CreateProductCategory>((ref) {
  return CreateProductCategory(ref.read(productCategoryRepositoryProvider));
});

final renameProductCategoryProvider = Provider<RenameProductCategory>((ref) {
  return RenameProductCategory(ref.read(productCategoryRepositoryProvider));
});

final setProductCategoryActiveProvider = Provider<SetProductCategoryActive>((
  ref,
) {
  return SetProductCategoryActive(ref.read(productCategoryRepositoryProvider));
});

/// All categories with product counts, for the management screen.
final productCategoriesProvider =
    FutureProvider.autoDispose<List<ProductCategorySummary>>((ref) {
      return ref.read(getProductCategoriesProvider).call();
    });

/// Active categories, for product forms and filters.
final activeProductCategoriesProvider =
    FutureProvider.autoDispose<List<ProductCategory>>((ref) {
      return ref.read(getActiveProductCategoriesProvider).call();
    });

/// Refreshes category lists and products (whose category names may change)
/// after a category write.
void invalidateProductCategoryData(WidgetRef ref) {
  ref.invalidate(productCategoriesProvider);
  ref.invalidate(activeProductCategoriesProvider);
  ref.invalidate(productsProvider);
}
