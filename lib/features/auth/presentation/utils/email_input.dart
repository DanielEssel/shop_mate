/// Email checks for the sign-in and sign-up forms. The server remains the
/// final judge; these only catch obvious mistakes early.
abstract final class EmailInput {
  /// One `@`, no spaces, and a dot in the domain followed by at least two
  /// characters.
  static final _pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@.]{2,}$');

  /// Common misspellings of popular providers. Kept small and conservative:
  /// only domains that are almost certainly a typo.
  static const _domainFixes = {
    'gmial.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yhoo.com': 'yahoo.com',
    'yahoo.co': 'yahoo.com',
    'hotmial.com': 'hotmail.com',
    'hotmal.com': 'hotmail.com',
    'hotmail.co': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outloo.com': 'outlook.com',
    'outlook.co': 'outlook.com',
  };

  static bool isValid(String input) => _pattern.hasMatch(input.trim());

  /// Form validator: null when [input] looks like an email address.
  static String? validate(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email address.';
    if (!isValid(value)) return 'Enter a valid email address.';
    return null;
  }

  /// The corrected address when [input] uses a known misspelled domain, or
  /// null. Only a complete address is checked, and the local part (before
  /// the `@`) is kept exactly as typed.
  static String? suggestCorrection(String input) {
    final value = input.trim();
    final at = value.lastIndexOf('@');
    if (at <= 0 || at != value.indexOf('@')) return null;

    final domain = value.substring(at + 1).toLowerCase();
    final fix = _domainFixes[domain];
    if (fix == null) return null;

    return '${value.substring(0, at)}@$fix';
  }
}
