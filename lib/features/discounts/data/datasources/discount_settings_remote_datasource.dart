import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/discount_settings_model.dart';

/// Reads the tables directly (row-level security scopes them to the
/// caller's shop). Writes only through `save_discount_settings`, which
/// checks that the caller is the shop's owner and saves the configuration
/// and its selection in one transaction; the tables themselves are
/// read-only for the app.
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

  /// Saves the caller's shop configuration and its exact selection, all or
  /// nothing. The shop is the caller's own; none is sent.
  Future<void> saveSettings({
    required bool isEnabled,
    required String scope,
    required String percentage,
    required String? endsAt,
    required List<String> productIds,
  }) async {
    await _client.rpc<void>(
      'save_discount_settings',
      params: {
        'p_is_enabled': isEnabled,
        'p_scope': scope,
        'p_percentage': percentage,
        'p_ends_at': endsAt,
        'p_product_ids': productIds,
      },
    );
  }
}
