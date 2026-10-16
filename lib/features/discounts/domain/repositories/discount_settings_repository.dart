import '../entities/discount_settings.dart';

/// The shop's discount configuration. Reads are limited to the caller's
/// shop; saving is limited to its owner by the database. Failures are
/// thrown as `DiscountSettingsException`.
abstract class DiscountSettingsRepository {
  /// The saved configuration, or null when the shop has none.
  Future<DiscountSettings?> getSettings();

  /// Saves [draft], including the selected-product list, for the caller's
  /// shop. The database checks that the caller is the owner and saves the
  /// configuration and the selection together: a failure changes nothing,
  /// and a sale sees either the old configuration or the new one.
  Future<void> saveSettings(DiscountSettingsDraft draft);
}
