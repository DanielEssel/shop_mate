import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_profile_update.dart';

Matcher _throwsKind(ShopBrandingErrorKind kind) {
  return throwsA(
    isA<ShopBrandingException>().having((e) => e.kind, 'kind', kind),
  );
}

void main() {
  test('trims the name and phone', () {
    final update = ShopProfileUpdate(
      name: "  Danny's Mini-Mart & Co. (No. 2)  ",
      phone: '  +233 (24) 123-4567  ',
    );

    expect(update.name, "Danny's Mini-Mart & Co. (No. 2)");
    expect(update.phone, '+233 (24) 123-4567');
  });

  test('a blank or missing phone becomes null', () {
    expect(ShopProfileUpdate(name: 'Shop A', phone: '   ').phone, isNull);
    expect(ShopProfileUpdate(name: 'Shop A').phone, isNull);
  });

  test('accepts names of 2 and 80 characters', () {
    expect(ShopProfileUpdate(name: 'AB').name, 'AB');
    expect(ShopProfileUpdate(name: 'n' * 80).name.length, 80);
  });

  for (final name in ['', '   ', 'A', 'n' * 81]) {
    test(
      'rejects the name "${name.length > 10 ? '${name.length} chars' : name}"',
      () {
        expect(
          () => ShopProfileUpdate(name: name),
          _throwsKind(ShopBrandingErrorKind.invalidName),
        );
      },
    );
  }

  for (final phone in [
    '0241234567',
    '+233 24 123 4567',
    '(030) 270-1234',
    '024.123.4567',
  ]) {
    test('accepts the phone "$phone"', () {
      expect(ShopProfileUpdate(name: 'Shop A', phone: phone).phone, phone);
    });
  }

  for (final phone in [
    'call me',
    '12-34',
    '1234567890123456',
    '024#1234567',
    '1' * 41,
  ]) {
    test('rejects the phone "$phone"', () {
      expect(
        () => ShopProfileUpdate(name: 'Shop A', phone: phone),
        _throwsKind(ShopBrandingErrorKind.invalidPhone),
      );
    });
  }
}
