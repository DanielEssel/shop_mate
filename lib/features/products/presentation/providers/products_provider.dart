import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/product_remote_datasource.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/get_low_stock_products.dart';
import '../../domain/usecases/update_product.dart';
import '../../domain/usecases/delete_product.dart';

final productDataSourceProvider =
    Provider<ProductRemoteDataSource>((ref) {
  return ProductRemoteDataSource(
    Supabase.instance.client,
  );
});

final updateProductProvider =
    Provider<UpdateProduct>((ref) {
  return UpdateProduct(
    ref.read(productRepositoryProvider),
  );
});

final deleteProductProvider =
    Provider<DeleteProduct>((ref) {
  return DeleteProduct(
    ref.read(productRepositoryProvider),
  );
});

final getLowStockProductsProvider =
    Provider<GetLowStockProducts>((ref) {
  return GetLowStockProducts(
    ref.read(productRepositoryProvider),
  );
});

final lowStockProductsProvider =
    FutureProvider<List<Product>>((ref) {
  return ref
      .read(getLowStockProductsProvider)
      .call();
});



final productRepositoryProvider =
    Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    ref.read(productDataSourceProvider),
  );
});

final createProductProvider =
    Provider<CreateProduct>((ref) {
  return CreateProduct(
    ref.read(productRepositoryProvider),
  );
});

final productsProvider =
    FutureProvider<List<Product>>((ref) async {
  final repository = ref.read(productRepositoryProvider);

  return repository.getProducts();
});

final productByIdProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  final repository =
      ref.read(productRepositoryProvider);

  return repository.getProductById(id);
});