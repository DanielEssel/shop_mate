import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/customer_payment_request.dart';
import '../models/customer_credit_statement_model.dart';
import '../models/customer_model.dart';

class CustomerRemoteDataSource {
  CustomerRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'customers';

  Future<List<CustomerModel>> getCustomers() async {
    final response = await _client
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (json) => CustomerModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<CustomerModel> getCustomerById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .single();

    return CustomerModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<CustomerCreditStatementModel> getCustomerCreditStatement(
    String customerId,
  ) async {
    final salesResponse = await _client
        .from('sales')
        .select(
          'id, sale_number, total_amount, created_at, '
          'customer_payment_allocations!customer_payment_allocations_sale_shop_fkey(amount)',
        )
        .eq('customer_id', customerId)
        .eq('payment_method', 'credit')
        .order('created_at', ascending: false);

    final paymentResponse = await _client
        .from('customer_payments')
        .select(
          'id, amount, payment_method, reference, note, paid_at, '
          'customer_payment_allocations!customer_payment_allocations_payment_shop_fkey('
          'sales!customer_payment_allocations_sale_shop_fkey(sale_number))',
        )
        .eq('customer_id', customerId)
        .order('paid_at', ascending: false);

    return CustomerCreditStatementModel.fromRows(
      creditSales: _toRows(salesResponse),
      payments: _toRows(paymentResponse),
    );
  }

  Future<void> recordCustomerPayment(
    RecordCustomerPaymentRequest request,
  ) async {
    await _client.rpc(
      'record_customer_payment',
      params: {
        'p_customer_id': request.customerId,
        'p_amount': request.amount,
        'p_payment_method': request.paymentMethod,
        'p_paid_at': request.paidAt.toUtc().toIso8601String(),
        'p_reference': request.reference,
        'p_note': request.note,
        'p_idempotency_key': request.idempotencyKey,
        'p_allocations': request.allocations
            .map(
              (allocation) => {
                'sale_id': allocation.saleId,
                'amount': allocation.amount,
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<CustomerModel> createCustomer(
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from(_table)
        .insert(data)
        .select()
        .single();

    return CustomerModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<CustomerModel> updateCustomer(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from(_table)
        .update({
          ...data,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return CustomerModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> deleteCustomer(String id) async {
    await _client
        .from(_table)
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  List<Map<String, Object?>> _toRows(Object? response) {
    if (response is! List) {
      throw const FormatException('Invalid customer credit response.');
    }

    return response
        .map((row) {
          if (row is! Map) {
            throw const FormatException('Invalid customer credit row.');
          }
          return Map<String, Object?>.from(row);
        })
        .toList(growable: false);
  }
}