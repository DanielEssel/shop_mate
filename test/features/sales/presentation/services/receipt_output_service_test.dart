import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/domain/entities/sale_item.dart';
import 'package:shopmate/features/sales/presentation/services/receipt_branding.dart';
import 'package:shopmate/features/sales/presentation/services/receipt_output_service.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';

/// A real 1x1 PNG.
final _pngLogo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

final _sale = Sale(
  id: 'sale-1',
  saleNumber: 'SA-0001',
  totalAmount: 60,
  paymentMethod: 'cash',
  amountPaid: 60,
  changeAmount: 0,
  createdAt: DateTime.utc(2026, 10, 6, 9),
);

final _items = [
  SaleItem(
    id: 'item-1',
    saleId: 'sale-1',
    productId: 'product-1',
    productName: 'Rice 5kg',
    quantity: 2,
    unitPrice: 30,
    costPrice: 20,
    subtotal: 60,
    createdAt: DateTime.utc(2026, 10, 6, 9),
  ),
];

ReceiptPdfData _data(ReceiptBranding branding) {
  return ReceiptPdfData(
    sale: _sale,
    items: _items,
    paidAmount: 60,
    paymentMethod: 'Cash',
    date: 'Oct 6, 2026',
    time: '9:00 AM',
    branding: branding,
  );
}

/// Counts image XObjects (a transparent PNG adds a soft-mask image too).
int _imageCount(Uint8List pdfBytes) {
  return RegExp(
    r'/Subtype\s*/Image',
  ).allMatches(latin1.decode(pdfBytes)).length;
}

ShopBrandingResult _brandingResult({
  String name = "Danny's Shop",
  String? phone = '0240000001',
  Uint8List? logo,
}) {
  return ShopBrandingResult(
    branding: ShopBranding(
      shopId: 'shop-1',
      name: name,
      phone: phone,
      logoPath: logo == null ? null : 'shop-1/logo-1.png',
    ),
    logoBytes: logo,
  );
}

void main() {
  final service = ReceiptOutputService();

  group('receipt generation', () {
    test('includes the logo when branding has logo bytes', () async {
      final bytes = await service.generatePdf(
        _data(
          ReceiptBranding(
            shopName: "Danny's Shop",
            phone: '0240000001',
            logoBytes: _pngLogo,
          ),
        ),
      );

      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(_imageCount(bytes), greaterThan(0));
    });

    test('without a logo still generates, with no image', () async {
      final bytes = await service.generatePdf(
        _data(const ReceiptBranding(shopName: "Danny's Shop")),
      );

      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(_imageCount(bytes), 0);
    });

    test('with no branding at all still generates', () async {
      final bytes = await service.generatePdf(_data(const ReceiptBranding()));

      expect(bytes, isNotEmpty);
      expect(_imageCount(bytes), 0);
    });

    test(
      'an undecodable logo is dropped instead of failing the receipt',
      () async {
        final bytes = await service.generatePdf(
          _data(
            ReceiptBranding(
              shopName: "Danny's Shop",
              logoBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
            ),
          ),
        );

        expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(_imageCount(bytes), 0);
      },
    );
  });

  group('logo sizing', () {
    test('large square logos shrink to the height bound', () {
      final size = ReceiptOutputService.fitLogo(1024, 1024);

      expect(size.width, ReceiptOutputService.logoMaxHeight);
      expect(size.height, ReceiptOutputService.logoMaxHeight);
    });

    test('wide logos shrink to the width bound, keeping proportions', () {
      final size = ReceiptOutputService.fitLogo(1000, 200);

      expect(size.width, ReceiptOutputService.logoMaxWidth);
      expect(size.height, closeTo(28, 0.0001));
      expect(size.width / size.height, closeTo(1000 / 200, 0.0001));
    });

    test('tall logos shrink to the height bound, keeping proportions', () {
      final size = ReceiptOutputService.fitLogo(300, 600);

      expect(size.height, ReceiptOutputService.logoMaxHeight);
      expect(size.width / size.height, closeTo(0.5, 0.0001));
    });

    test('small logos are not enlarged', () {
      final size = ReceiptOutputService.fitLogo(40, 20);

      expect(size.width, 40);
      expect(size.height, 20);
    });

    test('unknown dimensions fall back to the bounds', () {
      final size = ReceiptOutputService.fitLogo(0, 0);

      expect(size.width, ReceiptOutputService.logoMaxWidth);
      expect(size.height, ReceiptOutputService.logoMaxHeight);
    });
  });

  group('receipt branding from shop branding', () {
    test('carries name, phone and logo from the current branding', () {
      final branding = ReceiptBranding.from(
        branding: _brandingResult(logo: _pngLogo),
        fallbackShopName: 'Ignored',
      );

      expect(branding.shopName, "Danny's Shop");
      expect(branding.phone, '0240000001');
      expect(branding.logoBytes, same(_pngLogo));
    });

    test('uses the access name while branding is unavailable', () {
      final branding = ReceiptBranding.from(
        branding: null,
        fallbackShopName: '  Danny  ',
      );

      expect(branding.shopName, 'Danny');
      expect(branding.phone, isNull);
      expect(branding.logoBytes, isNull);
    });

    test('a failed logo download yields a logo-free receipt', () {
      final branding = ReceiptBranding.from(
        branding: ShopBrandingResult(
          branding: const ShopBranding(
            shopId: 'shop-1',
            name: "Danny's Shop",
            logoPath: 'shop-1/logo-1.png',
          ),
          logoError: const ShopBrandingException(
            ShopBrandingErrorKind.logoUnavailable,
          ),
        ),
      );

      expect(branding.shopName, "Danny's Shop");
      expect(branding.logoBytes, isNull);
    });

    test('blank values are treated as absent', () {
      final branding = ReceiptBranding.from(
        branding: _brandingResult(name: '  ', phone: ' '),
        fallbackShopName: 'Access Name',
      );

      expect(branding.shopName, 'Access Name');
      expect(branding.phone, isNull);
    });

    test('a new logo or a removed logo changes the receipt branding', () async {
      final before = ReceiptBranding.from(branding: _brandingResult());
      final withLogo = ReceiptBranding.from(
        branding: _brandingResult(logo: _pngLogo),
      );
      final removed = ReceiptBranding.from(branding: _brandingResult());

      expect(withLogo, isNot(before));
      expect(removed, isNot(withLogo));
      expect(removed, before);

      final withLogoPdf = await service.generatePdf(_data(withLogo));
      final removedPdf = await service.generatePdf(_data(removed));
      expect(_imageCount(withLogoPdf), greaterThan(0));
      expect(_imageCount(removedPdf), 0);
    });
  });
}
