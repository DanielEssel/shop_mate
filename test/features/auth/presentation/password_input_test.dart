import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/presentation/utils/password_input.dart';

void main() {
  group('new password', () {
    test('8 to 72 characters are accepted', () {
      expect(PasswordInput.validateNew('a' * 8), isNull);
      expect(PasswordInput.validateNew('a' * 72), isNull);
    });

    test('empty, 7 and 73 characters are rejected', () {
      expect(PasswordInput.validateNew(''), 'Enter a password.');
      expect(PasswordInput.validateNew(null), 'Enter a password.');
      expect(PasswordInput.validateNew('a' * 7), 'Use at least 8 characters.');
      expect(
        PasswordInput.validateNew('a' * 73),
        'Use 72 characters or fewer.',
      );
    });
  });

  group('confirmation', () {
    test('must be filled in and match exactly', () {
      expect(
        PasswordInput.validateConfirmation('', 'secret-pass'),
        'Confirm your password.',
      );
      expect(
        PasswordInput.validateConfirmation('secret-pass ', 'secret-pass'),
        'Passwords do not match.',
      );
      expect(
        PasswordInput.validateConfirmation('secret-pass', 'secret-pass'),
        isNull,
      );
    });
  });
}
