import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supplier_model.dart';

class SupplierRemoteDataSource {
  SupplierRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'suppliers';

  /// Reads suppliers visible to the caller. Row-level security limits rows
  /// to the caller's active shop, so no shop id is sent.
  Future<List<SupplierModel>> getSuppliers({
    required bool includeInactive,
  }) async {
    var query = _client.from(_table).select(SupplierModel.selectColumns);

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('name', ascending: true);

    return response
        .map((row) => SupplierModel.fromRow(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<SupplierModel> getSupplierById(String id) async {
    final response = await _client
        .from(_table)
        .select(SupplierModel.selectColumns)
        .eq('id', id)
        .single();

    return SupplierModel.fromRow(Map<String, Object?>.from(response));
  }

  /// Inserts only client-owned fields. The database supplies id, shop_id
  /// (`current_shop_id()`), is_active and timestamps, and enforces the
  /// active-name uniqueness and field limits.
  Future<SupplierModel> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _client
        .from(_table)
        .insert({
          'name': name.trim(),
          'phone': _optionalText(phone),
          'email': _optionalText(email),
          'address': _optionalText(address),
          'notes': _optionalText(notes),
        })
        .select(SupplierModel.selectColumns)
        .single();

    return SupplierModel.fromRow(Map<String, Object?>.from(response));
  }

  /// Updates editable fields only; id, shop_id, created_by and created_at are
  /// never sent. There is no updated_at trigger, so it is set here.
  Future<SupplierModel> updateSupplier({
    required String id,
    required String name,
    required bool isActive,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _client
        .from(_table)
        .update({
          'name': name.trim(),
          'phone': _optionalText(phone),
          'email': _optionalText(email),
          'address': _optionalText(address),
          'notes': _optionalText(notes),
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select(SupplierModel.selectColumns)
        .single();

    return SupplierModel.fromRow(Map<String, Object?>.from(response));
  }

  /// Trims surrounding whitespace and stores blank values as null, matching
  /// how the app records other optional text.
  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
