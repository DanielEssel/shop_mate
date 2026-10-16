import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/discount_settings_model.dart';

/// Direct table access; row-level security scopes every read and write to
/// the caller's shop and limits writes to its owner.
class DiscountSettingsRemoteDataSource {
  DiscountSettingsRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _settingsTable = 'shop_discount_settings';
  static const _productsTable = 'shop_discount_products';
  static const _settingsColumns =
      'shop_id, is_enabled, scope, percentage, ends_at, updated_at';

  Future<DiscountSettingsModel?> getSettings() async {
    final rows = await _client.from(_settingsTable).select(_settingsColumns);
    if (rows.isEmpty) return null;

    final selected = await _client.from(_productsTable).select('product_id');
    final ids = <String>{
      for (final row in selected)
        if (row['product_id'] case final String id) id,
    };

    return DiscountSettingsModel.fromRow(
      Map<String, Object?>.from(rows.first),
      selectedProductIds: ids,
    );
  }

  /// Creates the shop's configuration and returns its shop id (the database
  /// fills it from the caller's shop).
  Future<String> insertSettings(Map<String, Object?> values) async {
    final row = await _client
        .from(_settingsTable)
        .insert(values)
        .select('shop_id')
        .single();
    final shopId = row['shop_id'];
    if (shopId is! String) {
      throw const FormatException('Invalid discount settings response.');
    }
    return shopId;
  }

  /// Returns false when no row was updated (hidden by row-level security).
  Future<bool> updateSettings(
    String shopId,
    Map<String, Object?> values,
  ) async {
    final rows = await _client
        .from(_settingsTable)
        .update(values)
        .eq('shop_id', shopId)
        .select('shop_id');
    return rows.isNotEmpty;
  }

  /// Makes the shop's selection exactly [productIds]: removes every other
  /// product, then adds the missing ones (already-selected ones are left).
  Future<void> replaceSelection(String shopId, Set<String> productIds) async {
    final remove = _client.from(_productsTable).delete().eq('shop_id', shopId);
    if (productIds.isEmpty) {
      await remove;
      return;
    }

    final sorted = productIds.toList()..sort();
    await remove.not('product_id', 'in', '(${sorted.join(',')})');
    await _client
        .from(_productsTable)
        .upsert(
          [
            for (final id in sorted) {'product_id': id},
          ],
          onConflict: 'shop_id,product_id',
          ignoreDuplicates: true,
        );
  }
}
