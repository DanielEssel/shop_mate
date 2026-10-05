import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/shop/data/models/shop_branding_model.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';

const _shopId = 'aaaaaaaa-0000-4000-8000-000000000000';

Map<String, Object?> _row() {
  return {
    'id': _shopId,
    'name': "Danny's Shop",
    'phone': '0240000001',
    'logo_path': '$_shopId/logo-1760000000000.png',
  };
}

void main() {
  test('parses a full row', () {
    final ShopBranding branding = ShopBrandingModel.fromRow(_row());

    expect(branding.shopId, _shopId);
    expect(branding.name, "Danny's Shop");
    expect(branding.phone, '0240000001');
    expect(branding.logoPath, '$_shopId/logo-1760000000000.png');
    expect(branding.hasLogo, isTrue);
  });

  test('null phone and logo_path parse as null', () {
    final branding = ShopBrandingModel.fromRow({
      ..._row(),
      'phone': null,
      'logo_path': null,
    });

    expect(branding.phone, isNull);
    expect(branding.logoPath, isNull);
    expect(branding.hasLogo, isFalse);
  });

  test('missing optional fields parse as null', () {
    final branding = ShopBrandingModel.fromRow(
      _row()
        ..remove('phone')
        ..remove('logo_path'),
    );

    expect(branding.phone, isNull);
    expect(branding.logoPath, isNull);
  });

  final invalid = <String, Object?>{
    'id': 42,
    'name': null,
    'phone': 240000001,
    'logo_path': true,
  };

  invalid.forEach((field, value) {
    test('rejects an invalid $field', () {
      expect(
        () => ShopBrandingModel.fromRow({..._row(), field: value}),
        throwsFormatException,
      );
    });
  });

  test('rejects a missing id or name', () {
    expect(
      () => ShopBrandingModel.fromRow(_row()..remove('id')),
      throwsFormatException,
    );
    expect(
      () => ShopBrandingModel.fromRow(_row()..remove('name')),
      throwsFormatException,
    );
  });

  test('select columns are exactly the parsed fields', () {
    expect(ShopBrandingModel.selectColumns, 'id, name, phone, logo_path');
  });
}
