import '../entities/product_category.dart';
import '../entities/product_category_name.dart';
import '../repositories/product_category_repository.dart';

class RenameProductCategory {
  RenameProductCategory(this._repository);

  final ProductCategoryRepository _repository;

  Future<ProductCategory> call(String id, ProductCategoryName name) {
    return _repository.renameCategory(id, name);
  }
}
