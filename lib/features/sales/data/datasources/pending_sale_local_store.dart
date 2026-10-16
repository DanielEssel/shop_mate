import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/pending_sale_request.dart';
import '../../domain/entities/sale_request_exception.dart';
import '../../domain/repositories/pending_sale_store.dart';

/// Keeps the unresolved sale on the device (shared_preferences), one record
/// per account and shop, so it survives leaving the screen and restarting
/// the app. Every write is awaited and checked.
///
/// Abandoned requests are a string list per account and shop, one JSON
/// entry each, so an entry that cannot be read never affects the others
/// and is kept as it is.
class SharedPreferencesPendingSaleStore implements PendingSaleStore {
  SharedPreferencesPendingSaleStore(this._preferences);

  final Future<SharedPreferences> Function() _preferences;

  static String keyFor(PendingSaleScope scope) =>
      'shopmate.pending_sale.v1.${scope.userId}.${scope.shopId}';

  static String abandonedKeyFor(PendingSaleScope scope) =>
      'shopmate.abandoned_sales.v1.${scope.userId}.${scope.shopId}';

  @override
  Future<PendingSaleRequest?> load(PendingSaleScope scope) async {
    final String? raw;
    try {
      raw = (await _preferences()).getString(keyFor(scope));
    } catch (error) {
      throw PendingSaleStoreException('load', cause: error);
    }
    if (raw == null) return null;

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Not an object.');
      final request = PendingSaleRequest.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (request.scope != scope) {
        throw const FormatException('Saved for another account or shop.');
      }
      return request;
    } catch (error) {
      // Kept as it is: never silently dropped.
      throw PendingSaleStoreException('load', rawValue: raw, cause: error);
    }
  }

  @override
  Future<void> save(PendingSaleRequest request) async {
    final bool saved;
    try {
      saved = await (await _preferences()).setString(
        keyFor(request.scope),
        jsonEncode(request.toJson()),
      );
    } catch (error) {
      throw PendingSaleStoreException('save', cause: error);
    }
    if (!saved) throw const PendingSaleStoreException('save');
  }

  @override
  Future<void> delete(PendingSaleScope scope) async {
    final bool removed;
    try {
      removed = await (await _preferences()).remove(keyFor(scope));
    } catch (error) {
      throw PendingSaleStoreException('delete', cause: error);
    }
    if (!removed) throw const PendingSaleStoreException('delete');
  }

  @override
  Future<void> abandon(PendingSaleRequest request, DateTime abandonedAt) async {
    final scope = request.scope;
    final entries = await _abandonedEntries(scope);
    final alreadyKept = entries.any(
      (entry) =>
          _decode(entry, scope)?.request.idempotencyKey ==
          request.idempotencyKey,
    );
    if (!alreadyKept) {
      await _writeAbandoned(scope, [
        ...entries,
        jsonEncode(
          AbandonedSaleRequest(
            request: request,
            abandonedAt: abandonedAt,
          ).toJson(),
        ),
      ]);
    }
    await delete(scope);
  }

  @override
  Future<void> abandonUnreadable(
    PendingSaleScope scope,
    String rawValue,
  ) async {
    final entries = await _abandonedEntries(scope);
    if (!entries.contains(rawValue)) {
      await _writeAbandoned(scope, [...entries, rawValue]);
    }
    await delete(scope);
  }

  @override
  Future<List<AbandonedSaleRequest>> loadAbandoned(
    PendingSaleScope scope,
  ) async {
    return [
      for (final entry in await _abandonedEntries(scope))
        ?_decode(entry, scope),
    ];
  }

  @override
  Future<void> removeAbandoned(
    PendingSaleScope scope,
    String idempotencyKey,
  ) async {
    final entries = await _abandonedEntries(scope);
    final kept = [
      for (final entry in entries)
        if (_decode(entry, scope)?.request.idempotencyKey != idempotencyKey)
          entry,
    ];
    if (kept.length != entries.length) await _writeAbandoned(scope, kept);
  }

  Future<List<String>> _abandonedEntries(PendingSaleScope scope) async {
    try {
      return (await _preferences()).getStringList(abandonedKeyFor(scope)) ??
          const [];
    } catch (error) {
      // Includes a value of another type under the key: never overwritten.
      throw PendingSaleStoreException('load', cause: error);
    }
  }

  Future<void> _writeAbandoned(
    PendingSaleScope scope,
    List<String> entries,
  ) async {
    final bool saved;
    try {
      saved = await (await _preferences()).setStringList(
        abandonedKeyFor(scope),
        entries,
      );
    } catch (error) {
      throw PendingSaleStoreException('save', cause: error);
    }
    if (!saved) throw const PendingSaleStoreException('save');
  }

  /// Null for an entry that cannot be read or belongs to another scope.
  static AbandonedSaleRequest? _decode(String entry, PendingSaleScope scope) {
    try {
      final Object? decoded = jsonDecode(entry);
      if (decoded is! Map) return null;
      final abandoned = AbandonedSaleRequest.fromJson(
        Map<String, Object?>.from(decoded),
      );
      return abandoned.request.scope == scope ? abandoned : null;
    } catch (_) {
      return null;
    }
  }
}
