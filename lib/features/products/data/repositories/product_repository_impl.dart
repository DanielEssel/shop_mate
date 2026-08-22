import 'dart:typed_data';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._remoteDataSource);

  final ProductRemoteDataSource _remoteDataSource;

  @override
  Future<List<Product>> getProducts() {
    return _remoteDataSource.getProducts();
  }

  @override
  Future<List<Product>> getLowStockProducts() {
    return _remoteDataSource.getLowStockProducts();
  }

  @override
  Future<Product> getProductById(String id) {
    return _remoteDataSource.getProductById(id);
  }

  @override
  Future<Product> createProduct(Product product) {
    return _remoteDataSource.createProduct({
      'name': product.name,
      'category': product.category,
      'sku': product.sku,
      'barcode': product.barcode,
      'description': product.description,
      'cost_price': product.costPrice,
      'selling_price': product.sellingPrice,
      'stock_quantity': product.stockQuantity,
      'low_stock_threshold': product.lowStockThreshold,
      'is_active': product.isActive,
    });
  }

  @override
Future<Product> updateProduct(Product product) {
  return _remoteDataSource.updateProduct(
    product.id,
    {
      'name': product.name,
      'category': product.category,
      'sku': product.sku,
      'barcode': product.barcode,
      'description': product.description,
      'cost_price': product.costPrice,
      'selling_price': product.sellingPrice,
      'stock_quantity': product.stockQuantity,
      'low_stock_threshold': product.lowStockThreshold,
      'is_active': product.isActive,
    },
  );
}

@override
Future<void> deleteProduct(String productId) {
  return _remoteDataSource.deleteProduct(productId);
}

  @override
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String extension,
  }) {
    return _remoteDataSource.uploadProductImage(
      productId: productId,
      bytes: bytes,
      extension: extension,
    );
  }

  @override
  Future<void> updateProductImageUrl(
    String productId,
    String imageUrl,
  ) {
    return _remoteDataSource.updateProductImageUrl(
      productId,
      imageUrl,
    );
  }
}