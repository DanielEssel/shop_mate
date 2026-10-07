import '../../domain/entities/new_shop_attendant.dart';

class CreatedShopAttendantModel extends CreatedShopAttendant {
  const CreatedShopAttendantModel({
    required super.userId,
    required super.email,
    required super.displayName,
    required super.confirmationEmailSent,
  });

  /// The `create-shop-attendant` Edge Function's 201 response body.
  factory CreatedShopAttendantModel.fromJson(Map<String, Object?> json) {
    final userId = json['user_id'];
    final email = json['email'];
    final displayName = json['display_name'];
    final confirmationEmailSent = json['confirmation_email_sent'];
    if (userId is! String ||
        email is! String ||
        displayName is! String ||
        confirmationEmailSent is! bool) {
      throw const FormatException('Invalid create-shop-attendant response.');
    }

    return CreatedShopAttendantModel(
      userId: userId,
      email: email,
      displayName: displayName,
      confirmationEmailSent: confirmationEmailSent,
    );
  }
}
