import 'package:flutter/material.dart';

/// Shadows are for floating surfaces only (menus, sheets, dialogs, the
/// auth card). Content sections use hairline borders instead.
abstract final class AppShadows {
  /// A barely-there lift for surfaces that sit on imagery.
  static const card = [
    BoxShadow(color: Color(0x0A0F1A16), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const elevated = [
    BoxShadow(color: Color(0x140F1A16), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Hairline lift for primary metric surfaces.
  static const subtle = [
    BoxShadow(color: Color(0x080F1A16), blurRadius: 2, offset: Offset(0, 1)),
  ];
}
