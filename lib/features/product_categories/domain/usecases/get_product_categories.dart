import '../entities/product_category_summary.dart';
import '../repositories/product_category_repository.dart';

class GetProductCategories {
  GetProductCategories(this._repository);

  final ProductCategoryRepository _repository;

  Future<List<ProductCategorySummary>> call() => _repository.getCategories();
}
