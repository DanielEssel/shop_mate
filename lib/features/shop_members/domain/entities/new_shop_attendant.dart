import 'package:flutter/foundation.dart';

/// The details the owner enters for a new Shop Attendant login.
///
/// [temporaryPassword] only travels to the `create-shop-attendant` Edge
/// Function; it is never stored, logged or shown again. [toString] leaves it
/// out.
@immutable
class NewShopAttendant {
  const NewShopAttendant({
    required this.email,
    required this.displayName,
    required this.temporaryPassword,
  });

  final String email;
  final String displayName;
  final String temporaryPassword;

  @override
  String toString() => 'NewShopAttendant($email)';
}

/// The account the Edge Function created. It never includes the password.
@immutable
class CreatedShopAttendant {
  const CreatedShopAttendant({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.confirmationEmailSent,
  });

  final String userId;
  final String email;
  final String displayName;

  /// Whether the sign-up confirmation email went out. When false the
  /// attendant can resend it from the sign-in screen.
  final bool confirmationEmailSent;
}
