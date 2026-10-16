import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/pending_sale_request.dart';
import '../../domain/entities/sale_outcome.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
import '../models/sale_payment_summary_model.dart';

class SalesRemoteDataSource {
  SalesRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _salesTable = 'sales';
  static const _saleItemsTable = 'sale_items';
  static const _paymentAllocationsTable = 'customer_payment_allocations';

  /// `create_sale_idempotent`: records a standard (non-credit) sale at most
  /// once per key. The unprotected `create_sale` is never called from here.
  Future<SaleSubmission> createSaleIdempotent(
    PendingSaleRequest request,
  ) async {
    final Object? response = await _client.rpc(
      'create_sale_idempotent',
      params: {
        'p_idempotency_key': request.idempotencyKey,
        'p_customer_id': request.draft.customerId,
        'p_payment_method': request.draft.paymentMethod,
        'p_amount_paid': request.draft.amountPaid,
        'p_items': _items(request),
      },
    );
    // A set-returning function: one row of (sale_id, replayed).
    final Object? row = response is List && response.length == 1
        ? response.first
        : null;
    if (row is! Map) {
      throw const FormatException('Invalid create_sale_idempotent response.');
    }
    final saleId = row['sale_id'];
    final replayed = row['replayed'];
    if (saleId is! String || replayed is! bool) {
      throw const FormatException('Invalid create_sale_idempotent response.');
    }
    return SaleSubmission(saleId: saleId, replayed: replayed);
  }

  /// The existing credit function, unchanged; it cannot say whether a
  /// request was replayed.
  Future<SaleSubmission> createCreditSaleWithInitialPayment(
    PendingSaleRequest request,
  ) async {
    final customerId = request.draft.customerId;
    if (customerId == null) {
      throw ArgumentError('A credit sale needs a customer.');
    }
    final Object? response = await _client.rpc(
      'create_credit_sale_with_initial_payment',
      params: {
        'p_customer_id': customerId,
        'p_initial_payment_amount': request.draft.amountPaid,
        'p_initial_payment_method': request.draft.initialPaymentMethod,
        'p_items': _items(request),
        'p_idempotency_key': request.idempotencyKey,
      },
    );
    if (response is! String) {
      throw const FormatException(
        'Invalid create_credit_sale_with_initial_payment response.',
      );
    }
    return SaleSubmission(saleId: response);
  }

  /// `find_sale_by_idempotency_key`: read-only.
  Future<String?> findSaleByIdempotencyKey(String idempotencyKey) async {
    final Object? response = await _client.rpc(
      'find_sale_by_idempotency_key',
      params: {'p_key': idempotencyKey},
    );
    if (response == null) return null;
    if (response is! String) {
      throw const FormatException(
        'Invalid find_sale_by_idempotency_key response.',
      );
    }
    return response;
  }

  /// The items exactly as saved, in their saved order.
  static List<Map<String, Object>> _items(PendingSaleRequest request) => [
    for (final item in request.draft.items) item.toJson(),
  ];

  Future<List<SaleModel>> getSales() async {
    final response = await _client
        .from(_salesTable)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SaleModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<SaleModel> getSaleById(String id) async {
    final response = await _client
        .from(_salesTable)
        .select()
        .eq('id', id)
        .single();

    return SaleModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<SaleItemModel>> getSaleItems(String saleId) async {
    final response = await _client
        .from(_saleItemsTable)
        .select()
        .eq('sale_id', saleId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => SaleItemModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<SalePaymentSummaryModel> getSalePaymentSummary(String saleId) async {
    final response = await _client
        .from(_paymentAllocationsTable)
        .select(
          'amount, customer_payments!'
          'customer_payment_allocations_payment_shop_fkey(payment_method)',
        )
        .eq('sale_id', saleId)
        .order('created_at', ascending: true);

    final allocations = (response as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    return SalePaymentSummaryModel.fromAllocations(allocations);
  }
}
