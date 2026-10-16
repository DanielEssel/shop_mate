/// Whether this app build may save discount settings.
///
/// The discount tables are read-only for every API role. Owners save
/// through `save_discount_settings` (migration 20261016090000), which the
/// database restricts to the shop's owner; it is applied once the checkout
/// release that shows discounted prices has rolled out to every device.
///
/// Turn this on in a release that ships after that migration. While it is
/// off the screen still shows the saved configuration and lets owners
/// preview a discount's effect, but never attempts a write. If it is on and
/// the function is missing, saving fails with the same "not available yet"
/// message and nothing is written.
abstract final class DiscountReleaseGate {
  static const bool writesEnabled = false;
}
