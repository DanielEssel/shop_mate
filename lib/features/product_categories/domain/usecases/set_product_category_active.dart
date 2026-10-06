import '../entities/product_category.dart';
import '../repositories/product_category_repository.dart';

/// Archives or restores a category.
class SetProductCategoryActive {
  SetProductCategoryActive(this._repository);

  final ProductCategoryRepository _repository;

  Future<ProductCategory> call(String id, {required bool isActive}) {
    return _repository.setCategoryActive(id, isActive: isActive);
  }
}
