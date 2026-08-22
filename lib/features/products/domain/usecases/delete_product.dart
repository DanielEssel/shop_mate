import '../repositories/product_repository.dart';

class DeleteProduct {
  DeleteProduct(this._repository);

  final ProductRepository _repository;

  Future<void> call(String productId) {
    return _repository.deleteProduct(productId);
  }
}
