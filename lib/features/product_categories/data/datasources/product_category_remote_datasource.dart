import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_category_model.dart';

/// Direct, RLS-protected access to `product_categories`. The shop comes from
/// the database (`current_shop_id()` default and policies); no shop id is
/// ever sent, and only the owner's writes are accepted.
class ProductCategoryRemoteDataSource {
  ProductCategoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'product_categories';

  Future<List<ProductCategoryModel>> getCategories({
    required bool activeOnly,
  }) async {
    var query = _client.from(_table).select(ProductCategoryModel.selectColumns);
    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('name', ascending: true);
    return response
        .map(
          (row) => ProductCategoryModel.fromRow(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  /// Number of active products per category id (uncategorised excluded).
  Future<Map<String, int>> getActiveProductCounts() async {
    final response = await _client
        .from('products')
        .select('category_id')
        .eq('is_active', true)
        .not('category_id', 'is', null);

    final counts = <String, int>{};
    for (final row in response) {
      final categoryId = Map<String, Object?>.from(row)['category_id'];
      if (categoryId is! String) {
        throw const FormatException('Invalid product category_id.');
      }
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }
    return counts;
  }

  Future<ProductCategoryModel> createCategory(String name) async {
    final response = await _client
        .from(_table)
        .insert({'name': name})
        .select(ProductCategoryModel.selectColumns)
        .single();

    return ProductCategoryModel.fromRow(Map<String, Object?>.from(response));
  }

  /// `updated_at` is maintained by a database trigger.
  Future<ProductCategoryModel> updateCategory(
    String id, {
    String? name,
    bool? isActive,
  }) async {
    final response = await _client
        .from(_table)
        .update({'name': ?name, 'is_active': ?isActive})
        .eq('id', id)
        .select(ProductCategoryModel.selectColumns)
        .single();

    return ProductCategoryModel.fromRow(Map<String, Object?>.from(response));
  }
}
