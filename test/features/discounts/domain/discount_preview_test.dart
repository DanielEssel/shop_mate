import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/discounts/domain/entities/discount_pricing.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';

import '../fake_discount_settings_repository.dart';

/// discountProducts: rice 10.00/6.00, oil 19.99/5.00, sugar 7.00/6.80,
/// sweet 0.33/0.10, mint 0.10/0.00, loss 4.00/5.00.
void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  final rice = discountProducts[0];
  final oil = discountProducts[1];
  final sugar = discountProducts[2];
  final sweet = discountProducts[3];
  final loss = discountProducts[5];

  test('no configuration, disabled, or expired: normal price', () {
    for (final settings in [
      null,
      discountSettings(isEnabled: false),
      discountSettings(endsAt: now.subtract(const Duration(seconds: 1))),
      discountSettings(endsAt: now), // ends exactly now: expired
    ]) {
      final preview = DiscountPricing.preview(
        rice,
        settings: settings,
        now: now,
      );
      expect(preview.isDiscounted, isFalse);
      expect(preview.finalCents, 1000);
      expect(preview.percentageLabel, isNull);
      expect(preview.likelyRefused, isFalse);
    }
  });

  test('all products: exact cent rounding like the database', () {
    final settings = discountSettings(basisPoints: 1500);
    final sweetPreview = DiscountPricing.preview(
      sweet,
      settings: settings,
      now: now,
    );
    expect(sweetPreview.discountCents, 5); // 0.0495 -> 0.05
    expect(sweetPreview.finalCents, 28);
    expect(sweetPreview.percentageLabel, '15%');

    final oilPreview = DiscountPricing.preview(
      oil,
      settings: discountSettings(),
      now: now,
    );
    expect(oilPreview.finalCents, 1799); // 19.99 - 2.00
  });

  test('all products: a product the discount would take below cost keeps '
      'its normal price and is not refused', () {
    for (final product in [sugar, loss]) {
      final preview = DiscountPricing.preview(
        product,
        settings: discountSettings(),
        now: now,
      );
      expect(preview.isDiscounted, isFalse, reason: product.name);
      expect(preview.percentageBasisPoints, 0);
      expect(preview.likelyRefused, isFalse);
    }
  });

  test('selected products: only selected products are discounted', () {
    final settings = discountSettings(
      scope: DiscountScope.selectedProducts,
      selectedProductIds: {'oil'},
    );
    expect(
      DiscountPricing.preview(oil, settings: settings, now: now).finalCents,
      1799,
    );
    expect(
      DiscountPricing.preview(rice, settings: settings, now: now).isDiscounted,
      isFalse,
    );
  });

  test('selected products: an unsafe selected product will be refused', () {
    final preview = DiscountPricing.preview(
      sugar,
      settings: discountSettings(
        scope: DiscountScope.selectedProducts,
        selectedProductIds: {'sugar'},
      ),
      now: now,
    );
    expect(preview.likelyRefused, isTrue);
    expect(preview.isDiscounted, isFalse);
    expect(preview.finalCents, 700);
  });

  test('a discount that rounds to nothing records no percentage', () {
    final preview = DiscountPricing.preview(
      discountProduct('tiny', 'Tiny', price: 0.04, cost: 0),
      settings: discountSettings(),
      now: now,
    );
    expect(preview.isDiscounted, isFalse);
    expect(preview.percentageLabel, isNull);
  });
}
