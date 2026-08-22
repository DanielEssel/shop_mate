import 'package:supabase_flutter/supabase_flutter.dart';

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
}