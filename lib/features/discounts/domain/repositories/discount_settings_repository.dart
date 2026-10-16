import '../entities/discount_settings.dart';

/// The shop's discount configuration. Row-level security limits every read
/// and write to the caller's shop, and writes to its owner; failures are
/// thrown as `DiscountSettingsException`.
abstract class DiscountSettingsRepository {
  /// The saved configuration, or null when the shop has none.
  Future<DiscountSettings?> getSettings();

  /// Saves [draft] over [current] (null when there is none yet), including
  /// the selected-product list.
  ///
  /// The steps are ordered so that a failure part-way leaves the discount
  /// switched OFF (normal prices), never half-applied: the settings are
  /// saved disabled first, then the selection is synced, and only then is
  /// the discount enabled if [draft] asks for it.
  Future<void> saveSettings(
    DiscountSettingsDraft draft, {
    required DiscountSettings? current,
  });
}
