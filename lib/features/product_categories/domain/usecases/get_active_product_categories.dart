import '../entities/product_category.dart';
import '../repositories/product_category_repository.dart';

class GetActiveProductCategories {
  GetActiveProductCategories(this._repository);

  final ProductCategoryRepository _repository;

  Future<List<ProductCategory>> call() => _repository.getActiveCategories();
}
