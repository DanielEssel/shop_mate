import '../entities/product_category.dart';
import '../entities/product_category_name.dart';
import '../repositories/product_category_repository.dart';

class CreateProductCategory {
  CreateProductCategory(this._repository);

  final ProductCategoryRepository _repository;

  Future<ProductCategory> call(ProductCategoryName name) {
    return _repository.createCategory(name);
  }
}
