import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/discount_settings.dart';
import '../../domain/entities/discount_settings_exception.dart';
import '../../domain/repositories/discount_settings_repository.dart';
import '../datasources/discount_settings_remote_datasource.dart';

class DiscountSettingsRepositoryImpl implements DiscountSettingsRepository {
  DiscountSettingsRepositoryImpl(this._remoteDataSource);

  final DiscountSettingsRemoteDataSource _remoteDataSource;

  @override
  Future<DiscountSettings?> getSettings() async {
    try {
      return await _remoteDataSource.getSettings();
    } catch (error) {
      throw _translate(error, DiscountSettingsErrorKind.loadFailed);
    }
  }

  @override
  Future<void> saveSettings(
    DiscountSettingsDraft draft, {
    required DiscountSettings? current,
  }) async {
    try {
      // 1. The configuration, switched OFF: a later failure leaves normal
      //    prices rather than a half-applied discount.
      final values = <String, Object?>{
        'is_enabled': false,
        'scope': draft.scope.value,
        // Exact decimal text; never a floating-point number.
        'percentage': draft.percentage.databaseValue,
        'ends_at': draft.endsAt?.toUtc().toIso8601String(),
      };
      final String shopId;
      if (current == null) {
        shopId = await _remoteDataSource.insertSettings(values);
      } else {
        shopId = current.shopId;
        await _requireUpdated(_remoteDataSource.updateSettings(shopId, values));
      }

      // 2. The selected products (kept even while the scope is all products).
      await _remoteDataSource.replaceSelection(
        shopId,
        draft.selectedProductIds,
      );

      // 3. Only now switch it on, if asked.
      if (draft.isEnabled) {
        await _requireUpdated(
          _remoteDataSource.updateSettings(shopId, {'is_enabled': true}),
        );
      }
    } catch (error) {
      throw _translate(error, DiscountSettingsErrorKind.saveFailed);
    }
  }

  /// An update hidden by row-level security changes nothing without an
  /// error; it must never be reported as saved.
  static Future<void> _requireUpdated(Future<bool> update) async {
    if (!await update) {
      throw const DiscountSettingsException(
        DiscountSettingsErrorKind.permissionDenied,
      );
    }
  }

  /// PostgREST rejects an expired or invalid session with these codes.
  static const _sessionCodes = {'PGRST301', 'PGRST302', 'PGRST303'};

  /// Maps backend failures to a user-safe kind; the backend's text is
  /// dropped.
  static DiscountSettingsException _translate(
    Object error,
    DiscountSettingsErrorKind fallback,
  ) {
    if (error is DiscountSettingsException) return error;
    // A malformed row or response.
    if (error is FormatException) return DiscountSettingsException(fallback);
    // Like the rest of the app: anything that isn't a database answer is
    // treated as a connection problem.
    if (error is! PostgrestException) {
      return const DiscountSettingsException(DiscountSettingsErrorKind.network);
    }

    final code = error.code;
    final kind = switch (code) {
      // No privilege (the release gate), or row-level security.
      '42501' => DiscountSettingsErrorKind.permissionDenied,
      // Check constraint, bad number, number out of range.
      '23514' || '22P02' || '22003' => DiscountSettingsErrorKind.invalid,
      final String c when _sessionCodes.contains(c) =>
        DiscountSettingsErrorKind.permissionDenied,
      _ when error.message.contains('row-level security') =>
        DiscountSettingsErrorKind.permissionDenied,
      _ => fallback,
    };
    return DiscountSettingsException(kind, code: code);
  }
}
