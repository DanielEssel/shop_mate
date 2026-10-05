import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';

Uint8List _png([int length = 64]) {
  final bytes = Uint8List(length);
  bytes.setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return bytes;
}

Uint8List _jpeg([int length = 64]) {
  final bytes = Uint8List(length);
  bytes.setAll(0, [0xFF, 0xD8, 0xFF, 0xE0]);
  return bytes;
}

Matcher _throwsKind(ShopBrandingErrorKind kind) {
  return throwsA(
    isA<ShopBrandingException>().having((e) => e.kind, 'kind', kind),
  );
}

void main() {
  test('accepts a PNG', () {
    final upload = ShopLogoUpload(bytes: _png(), extension: 'png');

    expect(upload.extension, 'png');
    expect(upload.contentType, 'image/png');
  });

  test('accepts JPG and JPEG', () {
    expect(
      ShopLogoUpload(bytes: _jpeg(), extension: 'jpg').contentType,
      'image/jpeg',
    );
    expect(ShopLogoUpload(bytes: _jpeg(), extension: 'jpeg').extension, 'jpeg');
  });

  test('normalises case, spaces and a leading dot', () {
    expect(ShopLogoUpload(bytes: _png(), extension: ' .PNG ').extension, 'png');
    expect(ShopLogoUpload(bytes: _jpeg(), extension: 'JpG').extension, 'jpg');
  });

  test('accepts exactly 1 MiB', () {
    final upload = ShopLogoUpload(
      bytes: _png(ShopLogoUpload.maxBytes),
      extension: 'png',
    );

    expect(upload.bytes.length, 1048576);
  });

  test('rejects more than 1 MiB', () {
    expect(
      () => ShopLogoUpload(
        bytes: _png(ShopLogoUpload.maxBytes + 1),
        extension: 'png',
      ),
      _throwsKind(ShopBrandingErrorKind.tooLarge),
    );
  });

  test('rejects empty bytes', () {
    expect(
      () => ShopLogoUpload(bytes: Uint8List(0), extension: 'png'),
      _throwsKind(ShopBrandingErrorKind.emptyFile),
    );
  });

  for (final extension in ['gif', 'webp', 'svg', '', 'png.exe']) {
    test('rejects extension "$extension"', () {
      expect(
        () => ShopLogoUpload(bytes: _png(), extension: extension),
        _throwsKind(ShopBrandingErrorKind.invalidFormat),
      );
    });
  }

  test('rejects content that does not match the extension', () {
    expect(
      () => ShopLogoUpload(bytes: _jpeg(), extension: 'png'),
      _throwsKind(ShopBrandingErrorKind.invalidFormat),
    );
    expect(
      () => ShopLogoUpload(bytes: _png(), extension: 'jpg'),
      _throwsKind(ShopBrandingErrorKind.invalidFormat),
    );
  });

  test('every error kind has a user-safe message', () {
    for (final kind in ShopBrandingErrorKind.values) {
      expect(kind.message, isNotEmpty);
      expect(ShopBrandingException(kind).message, kind.message);
    }
  });
}
