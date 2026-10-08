/// Corner radii. Three working values plus pill:
///
/// - [sm]: badges, chips, small icon tiles
/// - [md]: inputs, buttons, list rows, menus
/// - [lg]: cards, sections, sheets, dialogs
///
/// [xl] is reserved for full-screen hero panels (auth and shop gate cards).
abstract final class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 20.0;
  static const pill = 999.0;
}
