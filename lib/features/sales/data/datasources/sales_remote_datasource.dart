import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sale_item_model.dart';
import '../models/sale_model.dart';

class SalesRemoteDataSource {
  SalesRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _salesTable = 'sales';
  static const _saleItemsTable = 'sale_items';

  Future<String> createSale({
  String? customerId,
  required List<Map<String, dynamic>> items,
  required String paymentMethod,
  required double amountPaid,
}) async {
  final response = await _client.rpc(
    'create_sale',
    params: {
      'p_customer_id': customerId,
      'p_payment_method': paymentMethod,
      'p_amount_paid': amountPaid,
      'p_items': items,
    },
  );

  return response.toString();
}

  Future<List<SaleModel>> getSales() async {
    final response = await _client
        .from(_salesTable)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (json) => SaleModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<SaleModel> getSaleById(String id) async {
    final response = await _client
        .from(_salesTable)
        .select()
        .eq('id', id)
        .single();

    return SaleModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<SaleItemModel>> getSaleItems(
    String saleId,
  ) async {
    final response = await _client
        .from(_saleItemsTable)
        .select()
        .eq('sale_id', saleId)
        .order('created_at', ascending: true);

    return (response as List)
        .map(
          (json) => SaleItemModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }
}
