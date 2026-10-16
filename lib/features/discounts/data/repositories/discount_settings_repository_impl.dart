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
  Future<void> saveSettings(DiscountSettingsDraft draft) async {
    try {
      await _remoteDataSource.saveSettings(
        isEnabled: draft.isEnabled,
        scope: draft.scope.value,
        // Exact decimal text; never a floating-point number.
        percentage: draft.percentage.databaseValue,
        endsAt: draft.endsAt?.toUtc().toIso8601String(),
        productIds: draft.selectedProductIds.toList()..sort(),
      );
    } catch (error) {
      throw _translate(error, DiscountSettingsErrorKind.saveFailed);
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
      // Not the shop's owner (or no active shop), or row-level security.
      '42501' => DiscountSettingsErrorKind.permissionDenied,
      // save_discount_settings is not in the database yet: no fallback to
      // writing the tables directly.
      'PGRST202' || '42883' => DiscountSettingsErrorKind.writesNotAvailable,
      // save_discount_settings' own rules, by SQLSTATE.
      'SMD02' => DiscountSettingsErrorKind.unsafeSelection,
      'SMD03' => DiscountSettingsErrorKind.noProductsSelected,
      'SMD04' => DiscountSettingsErrorKind.endDateInPast,
      // Check constraint, bad or missing value, number out of range, or a
      // product that is not in this shop.
      '23514' ||
      '22P02' ||
      '22003' ||
      '22023' => DiscountSettingsErrorKind.invalid,
      final String c when _sessionCodes.contains(c) =>
        DiscountSettingsErrorKind.permissionDenied,
      _ when error.message.contains('row-level security') =>
        DiscountSettingsErrorKind.permissionDenied,
      _ => fallback,
    };
    return DiscountSettingsException(kind, code: code);
  }
}
