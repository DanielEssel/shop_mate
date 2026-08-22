import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_summary_model.dart';
import '../models/stock_movement_model.dart';

class InventoryRemoteDataSource {
  InventoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<InventorySummaryModel> getInventorySummary() async {
    final response = await _client
        .from('products')
        .select(
          'stock_quantity, low_stock_threshold',
        )
        .eq('is_active', true);

    return InventorySummaryModel.fromProducts(
      (response as List)
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList(),
    );
  }

  Future<String> adjustStock({
  required String productId,
  required int quantity,
  required String direction,
  String? note,
}) async {
  final dbDirection = switch (direction) {
    'increase' => 'in',
    'decrease' => 'out',
    _ => throw ArgumentError(
        'Invalid stock direction: $direction',
      ),
  };

  final response = await _client.rpc(
    'adjust_stock',
    params: {
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_direction': dbDirection,
      'p_note': note,
    },
  );

  return response.toString();
}

  Future<List<StockMovementModel>> getStockMovements({
    String? productId,
  }) async {
    var query = _client
    .from('stock_movements')
    .select(
      'id, product_id, movement_type, quantity, '
      'previous_quantity, new_quantity, reference_id, '
      'note, created_by, created_at',
    );

    if (productId != null) {
      query = query.eq(
        'product_id',
        productId,
      );
    }

    final response = await query.order(
      'created_at',
      ascending: false,
    );

    return (response as List)
        .map(
          (json) => StockMovementModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }
}
