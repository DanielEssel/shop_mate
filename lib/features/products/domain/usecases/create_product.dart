import '../entities/product.dart';
import '../repositories/product_repository.dart';

class CreateProduct {
  CreateProduct(this._repository);

  final ProductRepository _repository;

  Future<Product> call(Product product) {
    return _repository.createProduct(product);
  }
}