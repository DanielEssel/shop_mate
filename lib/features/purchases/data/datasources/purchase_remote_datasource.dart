import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase_item_model.dart';
import '../models/purchase_model.dart';

class PurchaseRemoteDataSource {
  PurchaseRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _purchasesTable = 'purchases';
  static const _purchaseItemsTable = 'purchase_items';

  Future<String> createPurchase({
    String? supplierName,
    String? supplierPhone,
    required String paymentMethod,
    required double amountPaid,
    required DateTime purchaseDate,
    String? notes,
    required List<Map<String, dynamic>> items,
    String? supplierId,
  }) async {
    final params = <String, Object?>{
      'p_supplier_name': supplierName,
      'p_supplier_phone': supplierPhone,
      'p_payment_method': paymentMethod,
      'p_amount_paid': amountPaid,
      'p_purchase_date': purchaseDate.toIso8601String().split('T').first,
      'p_notes': notes,
      'p_items': items,
    };

    // Unlinked purchases keep the original 7-parameter request; the trailing
    // p_supplier_id is sent only when a supplier is linked.
    if (supplierId != null) {
      params['p_supplier_id'] = supplierId;
    }

    final response = await _client.rpc('create_purchase', params: params);

    return response.toString();
  }

  Future<List<PurchaseModel>> getPurchases() async {
    final response = await _client
        .from(_purchasesTable)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PurchaseModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<PurchaseModel> getPurchaseById(String id) async {
    final response = await _client
        .from(_purchasesTable)
        .select()
        .eq('id', id)
        .single();

    return PurchaseModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<PurchaseItemModel>> getPurchaseItems(String purchaseId) async {
    final response = await _client
        .from(_purchaseItemsTable)
        .select()
        .eq('purchase_id', purchaseId)
        .order('created_at', ascending: true);

    return (response as List)
        .map(
          (json) => PurchaseItemModel.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }
}
