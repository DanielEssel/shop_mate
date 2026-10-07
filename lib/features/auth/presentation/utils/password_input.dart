/// Password rules for creating or changing a password. ShopMate asks for a
/// little more than Supabase's default minimum of 6; 72 is the most the
/// password hash uses.
abstract final class PasswordInput {
  static const minLength = 8;
  static const maxLength = 72;

  static const helperText = 'At least $minLength characters.';

  /// Form validator for a new password.
  static String? validateNew(String? input) {
    final password = input ?? '';
    if (password.isEmpty) return 'Enter a password.';
    if (password.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    if (password.length > maxLength) {
      return 'Use $maxLength characters or fewer.';
    }
    return null;
  }

  /// Form validator for the "confirm password" field.
  static String? validateConfirmation(String? input, String password) {
    if ((input ?? '').isEmpty) return 'Confirm your password.';
    if (input != password) return 'Passwords do not match.';
    return null;
  }
}
