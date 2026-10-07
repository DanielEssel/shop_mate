import 'dart:convert';

/// Field rules for the Add Shop Attendant form. They match the
/// `create-shop-attendant` Edge Function's own checks, which remain the final
/// judge; these only catch mistakes before the request is sent.
abstract final class AttendantInput {
  static const maxNameLength = 80;
  static const maxEmailLength = 254;
  static const minPasswordLength = 8;

  /// The most the password hash uses, in UTF-8 bytes.
  static const maxPasswordBytes = 72;

  static const passwordHelperText =
      'The attendant will use this temporary password to sign in. They should '
      'change it after their first login.';

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@.]{2,}$');
  static final _controlCharacters = RegExp(r'[\u0000-\u001f\u007f]');

  /// The name as it is sent: surrounding spaces removed.
  static String normalizeName(String input) => input.trim();

  /// The email as it is sent: trimmed and lowercased.
  static String normalizeEmail(String input) => input.trim().toLowerCase();

  static String? validateName(String? input) {
    final name = normalizeName(input ?? '');
    if (name.isEmpty) return "Enter the attendant's full name.";
    if (name.runes.length > maxNameLength) {
      return 'Use $maxNameLength characters or fewer.';
    }
    if (_controlCharacters.hasMatch(name)) {
      return 'Remove line breaks and tabs from the name.';
    }
    return null;
  }

  static String? validateEmail(String? input) {
    final email = normalizeEmail(input ?? '');
    if (email.isEmpty) return "Enter the attendant's email address.";
    if (email.length > maxEmailLength || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// The password is sent exactly as typed; [email] is the email field's
  /// current text.
  static String? validateTemporaryPassword(String? input, String email) {
    final password = input ?? '';
    if (password.isEmpty) return 'Enter a temporary password.';
    if (password.trim().isEmpty) return 'The password cannot be only spaces.';
    if (password.runes.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (utf8.encode(password).length > maxPasswordBytes) {
      return 'Use a shorter password ($maxPasswordBytes characters or fewer).';
    }
    if (password.trim().toLowerCase() == normalizeEmail(email)) {
      return 'The password cannot be the email address.';
    }
    return null;
  }
}
