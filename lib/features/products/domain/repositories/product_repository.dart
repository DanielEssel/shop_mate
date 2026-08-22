import 'dart:typed_data';

import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts();

  Future<List<Product>> getLowStockProducts();

  Future<Product> getProductById(
    String id,
  );

  Future<Product> createProduct(
    Product product,
  );

  Future<Product> updateProduct(
  Product product,
);

Future<void> deleteProduct(
  String productId,
);

  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String extension,
  });

  Future<void> updateProductImageUrl(
    String productId,
    String imageUrl,
  );
}