import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/shop_logo_upload.dart';
import '../models/shop_branding_model.dart';

/// One call per backend operation. The caller (the repository) decides the
/// order of operations; this class never deletes or rolls back on its own.
class ShopBrandingRemoteDataSource {
  ShopBrandingRemoteDataSource(this._client, {int Function()? nowMillis})
    : _nowMillis = nowMillis ?? _systemNowMillis;

  final SupabaseClient _client;
  final int Function() _nowMillis;

  static const _table = 'shops';
  static const bucket = 'shop-branding';

  static int _systemNowMillis() => DateTime.now().millisecondsSinceEpoch;

  /// Reads the shop row. Row-level security only returns the caller's own
  /// shop, so another shop's id yields no row.
  Future<ShopBrandingModel> fetchBranding(String shopId) async {
    final response = await _client
        .from(_table)
        .select(ShopBrandingModel.selectColumns)
        .eq('id', shopId)
        .single();

    return ShopBrandingModel.fromRow(Map<String, Object?>.from(response));
  }

  /// Downloads a logo from the private bucket with the caller's session.
  Future<Uint8List> downloadLogo(String logoPath) {
    return _client.storage.from(bucket).download(logoPath);
  }

  /// A new versioned path, `<shop id>/logo-<epoch ms>.<ext>`, matching the
  /// path contract enforced by the bucket policies and `set_shop_logo`.
  String newLogoPath(String shopId, String extension) {
    return '$shopId/logo-${_nowMillis()}.$extension';
  }

  /// Uploads to a new path; never overwrites (`upsert: false`).
  Future<void> uploadLogoObject(String logoPath, ShopLogoUpload upload) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          logoPath,
          upload.bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: upload.contentType,
          ),
        );
  }

  /// Points the current shop at an uploaded logo; returns the stored path.
  Future<String> setShopLogo(String logoPath) async {
    final Object? response = await _client.rpc(
      'set_shop_logo',
      params: {'p_path': logoPath},
    );

    if (response is! String) {
      throw const FormatException('Invalid set_shop_logo response.');
    }
    return response;
  }

  /// Clears the current shop's logo; returns the previous path, if any.
  Future<String?> clearShopLogo() async {
    final Object? response = await _client.rpc('clear_shop_logo');

    if (response == null) return null;
    if (response is! String) {
      throw const FormatException('Invalid clear_shop_logo response.');
    }
    return response;
  }

  /// Saves the current shop's business name and phone. The RPC resolves the
  /// shop from the caller's session and only accepts the shop owner.
  Future<void> updateShopProfile({required String name, String? phone}) async {
    await _client.rpc(
      'update_shop_profile',
      params: {'p_name': name, 'p_phone': phone},
    );
  }

  Future<void> deleteLogoObjects(List<String> logoPaths) async {
    await _client.storage.from(bucket).remove(logoPaths);
  }
}
