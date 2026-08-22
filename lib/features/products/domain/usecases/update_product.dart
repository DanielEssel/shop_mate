import '../entities/product.dart';
import '../repositories/product_repository.dart';

class UpdateProduct {
  UpdateProduct(this._repository);

  final ProductRepository _repository;

  Future<Product> call(Product product) {
    return _repository.updateProduct(product);
  }
}
