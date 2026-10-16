/// Whether this app build may save discount settings.
///
/// The database currently lets every API role READ discount settings only.
/// Writes are opened by a separate release-gating migration (it grants the
/// owner INSERT/UPDATE on shop_discount_settings and INSERT/DELETE on
/// shop_discount_products) once the checkout release that shows discounted
/// prices has rolled out to every device.
///
/// Turn this on in the same release as, or after, that migration. While it
/// is off the screen still shows the saved configuration and lets owners
/// preview a discount's effect, but never attempts a write.
abstract final class DiscountReleaseGate {
  static const bool writesEnabled = false;
}
