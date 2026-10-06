import 'package:flutter/foundation.dart';

import 'shop_branding_exception.dart';

/// A validated business name and phone, ready to save. Mirrors the
/// `update_shop_profile` RPC rules, which remain authoritative.
@immutable
class ShopProfileUpdate {
  const ShopProfileUpdate._({required this.name, required this.phone});

  /// Trims both values; a blank phone becomes null. Throws
  /// [ShopBrandingException] when a value is unacceptable.
  factory ShopProfileUpdate({required String name, String? phone}) {
    final trimmedName = name.trim();
    if (!isValidName(trimmedName)) {
      throw const ShopBrandingException(ShopBrandingErrorKind.invalidName);
    }

    final trimmedPhone = phone?.trim();
    final cleanPhone = trimmedPhone == null || trimmedPhone.isEmpty
        ? null
        : trimmedPhone;
    if (cleanPhone != null && !isValidPhone(cleanPhone)) {
      throw const ShopBrandingException(ShopBrandingErrorKind.invalidPhone);
    }

    return ShopProfileUpdate._(name: trimmedName, phone: cleanPhone);
  }

  /// Same bounds as shop registration.
  static const minNameLength = 2;
  static const maxNameLength = 80;
  static const maxPhoneLength = 40;

  static final _phoneCharacters = RegExp(r'^[0-9+() .-]+$');

  /// 2 to 80 characters after trimming (counted like Postgres `char_length`).
  static bool isValidName(String name) {
    final length = name.trim().runes.length;
    return length >= minNameLength && length <= maxNameLength;
  }

  /// Local or international formats: digits, spaces and `+ ( ) - .`, with 7
  /// to 15 digits in total.
  static bool isValidPhone(String phone) {
    if (phone.length > maxPhoneLength) return false;
    if (!_phoneCharacters.hasMatch(phone)) return false;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digits >= 7 && digits <= 15;
  }

  final String name;
  final String? phone;
}
