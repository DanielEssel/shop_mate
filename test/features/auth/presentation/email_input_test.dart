import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/presentation/utils/email_input.dart';

void main() {
  group('suggestCorrection', () {
    const typos = {
      'ama@gmial.com': 'ama@gmail.com',
      'ama@gmal.com': 'ama@gmail.com',
      'ama@gmail.co': 'ama@gmail.com',
      'kofi@yaho.com': 'kofi@yahoo.com',
      'kofi@yhoo.com': 'kofi@yahoo.com',
      'esi@hotmial.com': 'esi@hotmail.com',
      'esi@outlok.com': 'esi@outlook.com',
    };

    typos.forEach((typed, expected) {
      test('$typed -> $expected', () {
        expect(EmailInput.suggestCorrection(typed), expected);
      });
    });

    test('keeps the local part exactly and ignores domain case', () {
      expect(
        EmailInput.suggestCorrection('  Ama.Owusu+shop@GMIAL.com '),
        'Ama.Owusu+shop@gmail.com',
      );
    });

    test('valid and unknown domains get no suggestion', () {
      for (final email in [
        'ama@gmail.com',
        'kofi@yahoo.com',
        'esi@outlook.com',
        'owner@myshop.com.gh',
        'owner@company.co',
      ]) {
        expect(EmailInput.suggestCorrection(email), isNull, reason: email);
      }
    });

    test('incomplete input gets no suggestion', () {
      for (final email in ['', 'ama', 'ama@', '@gmial.com', 'a@b@gmial.com']) {
        expect(EmailInput.suggestCorrection(email), isNull, reason: email);
      }
    });
  });

  group('validate', () {
    test('accepts ordinary addresses', () {
      for (final email in [
        'ama@gmail.com',
        ' owner@shop.com.gh ',
        'a.b+c@sub.example.org',
      ]) {
        expect(EmailInput.validate(email), isNull, reason: email);
      }
    });

    test('rejects empty and malformed input', () {
      expect(EmailInput.validate(''), 'Enter your email address.');
      expect(EmailInput.validate('   '), 'Enter your email address.');
      for (final email in [
        'ama',
        'ama@',
        'ama@gmail',
        'ama@gmail.c',
        'ama gh@gmail.com',
        'ama@@gmail.com',
      ]) {
        expect(
          EmailInput.validate(email),
          'Enter a valid email address.',
          reason: email,
        );
      }
    });
  });
}
