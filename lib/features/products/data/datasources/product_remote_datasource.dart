import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';

class ProductRemoteDataSource {
  ProductRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'products';
  static const _bucket = 'product-images';

  Future<List<ProductModel>> getProducts() async {
    final response = await _client
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (json) => ProductModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<ProductModel> createProduct(
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from(_table)
        .insert(data)
        .select()
        .single();

    return ProductModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ProductModel> getProductById(
    String id,
  ) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .single();

    return ProductModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<ProductModel>> getLowStockProducts() async {
  final response = await _client
      .from(_table)
      .select()
      .eq('is_active', true)
      .order(
        'stock_quantity',
        ascending: true,
      );

  final products = (response as List)
      .map(
        (json) => ProductModel.fromJson(
          Map<String, dynamic>.from(json),
        ),
      )
      .toList();

  return products.where((product) {
    return product.stockQuantity <=
        product.lowStockThreshold;
  }).toList();
}


Future<ProductModel> updateProduct(
  String id,
  Map<String, dynamic> data,
) async {
  final response = await _client
      .from(_table)
      .update(data)
      .eq('id', id)
      .select()
      .single();

  return ProductModel.fromJson(
    Map<String, dynamic>.from(response),
  );
}

Future<void> deleteProduct(
  String id,
) async {
  await _client
      .from(_table)
      .update({
        'is_active': false,
      })
      .eq('id', id);
}

  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final filePath =
        '$productId.$extension';

    await _client.storage
        .from(_bucket)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentType(extension),
          ),
        );

    return _client.storage
        .from(_bucket)
        .getPublicUrl(filePath);
  }

  Future<void> updateProductImageUrl(
    String productId,
    String imageUrl,
  ) async {
    await _client
        .from(_table)
        .update({
          'image_url': imageUrl,
        })
        .eq('id', productId);
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}