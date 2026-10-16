import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/discounts/domain/entities/discount_percentage.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_pricing.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings_exception.dart';
import 'package:shopmate/features/discounts/domain/usecases/save_discount_settings.dart';

import '../fake_discount_settings_repository.dart';

DiscountPercentage _pct(String text) => DiscountPercentage.tryParse(text)!;

Matcher _throwsKind(DiscountSettingsErrorKind kind) => throwsA(
  isA<DiscountSettingsException>().having((e) => e.kind, 'kind', kind),
);

void main() {
  group('DiscountPercentage', () {
    test('accepts 0.01 through 99.99 with up to two decimals', () {
      for (final (text, basisPoints) in [
        ('0.01', 1),
        ('99.99', 9999),
        ('10', 1000),
        ('12.5', 1250),
        ('12.50', 1250),
        ('7.05', 705),
        (' 15 ', 1500),
      ]) {
        expect(DiscountPercentage.validate(text), isNull, reason: text);
        expect(DiscountPercentage.tryParse(text)!.basisPoints, basisPoints);
      }
    });

    test(
      'rejects zero, 100 and above, negatives, too many decimals and junk',
      () {
        final cases = {
          '': 'Enter a discount percentage.',
          '   ': 'Enter a discount percentage.',
          '0': 'The discount must be at least 0.01%.',
          '0.00': 'The discount must be at least 0.01%.',
          '100': 'The discount must be below 100%.',
          '100.00': 'The discount must be below 100%.',
          '250': 'The discount must be below 100%.',
          '123456789': 'The discount must be below 100%.',
          '-5': 'The discount must be at least 0.01%.',
          '-0.5': 'The discount must be at least 0.01%.',
          '10.555': 'Use at most two decimal places.',
          '0.001': 'Use at most two decimal places.',
          'abc': 'Enter a number such as 10 or 12.5.',
          '10%': 'Enter a number such as 10 or 12.5.',
          '1,5': 'Enter a number such as 10 or 12.5.',
          '1.2.3': 'Enter a number such as 10 or 12.5.',
          '.5': 'Enter a number such as 10 or 12.5.',
          '5.': 'Enter a number such as 10 or 12.5.',
          '--5': 'Enter a number such as 10 or 12.5.',
          '1e2': 'Enter a number such as 10 or 12.5.',
        };
        for (final MapEntry(key: text, value: message) in cases.entries) {
          expect(DiscountPercentage.validate(text), message, reason: text);
          expect(DiscountPercentage.tryParse(text), isNull, reason: text);
        }
      },
    );

    test('exact text for the database and for display', () {
      expect(_pct('12.5').databaseValue, '12.50');
      expect(_pct('0.01').databaseValue, '0.01');
      expect(_pct('99.99').databaseValue, '99.99');
      expect(_pct('10').databaseValue, '10.00');
      expect(_pct('10').label, '10%');
      expect(_pct('12.50').label, '12.5%');
      expect(_pct('7.05').label, '7.05%');
      expect(_pct('7.05').inputText, '7.05');
    });

    test('reads the database value whether sent as a number or text', () {
      expect(DiscountPercentage.fromDatabase(12.5).basisPoints, 1250);
      expect(DiscountPercentage.fromDatabase(10).basisPoints, 1000);
      expect(DiscountPercentage.fromDatabase(0.01).basisPoints, 1);
      expect(DiscountPercentage.fromDatabase(99.99).basisPoints, 9999);
      expect(DiscountPercentage.fromDatabase('12.50').basisPoints, 1250);
      expect(DiscountPercentage.fromDatabase('12.500').basisPoints, 1250);
      expect(() => DiscountPercentage.fromDatabase(0), throwsFormatException);
      expect(
        () => DiscountPercentage.fromDatabase(null),
        throwsFormatException,
      );
      expect(
        () => DiscountPercentage.fromDatabase(true),
        throwsFormatException,
      );
    });
  });

  group('DiscountPricing (same values as the database tests)', () {
    int discount(double price, String percent) => DiscountPricing.discountCents(
      DiscountPricing.toCents(price),
      _pct(percent),
    );

    test(
      'per-unit discount rounds half away from zero, like numeric round',
      () {
        expect(discount(10.00, '10'), 100); // 9.00
        expect(discount(19.99, '10'), 200); // 1.999 -> 2.00 -> 17.99
        expect(discount(0.33, '15'), 5); // 0.0495 -> 0.05
        expect(discount(0.10, '15'), 2); // 0.015 -> 0.02 (half up)
        expect(discount(2.50, '12.5'), 31); // 0.3125 -> 0.31
        expect(discount(0.10, '99.99'), 10); // 0.09999 -> 0.10
        expect(discount(10.00, '0.01'), 0); // 0.001 -> 0.00
        expect(discount(0.05, '10'), 1); // 0.005 -> 0.01 (half up)
        expect(discount(0.04, '10'), 0); // 0.004 -> 0.00
      },
    );

    test('final price and below-cost detection', () {
      final rice = DiscountPricing.priceOf(discountProducts[0], _pct('10'));
      expect(rice.finalCents, 900);
      expect(rice.isBelowCost, isFalse);

      final sugar = DiscountPricing.priceOf(discountProducts[2], _pct('10'));
      expect(sugar.finalCents, 630);
      expect(sugar.costCents, 680);
      expect(sugar.isBelowCost, isTrue);
      expect(sugar.shortfallCents, 50);

      // Already below cost but not discounted (rounds to 0): not flagged.
      final loss = discountProduct('l', 'L', price: 0.04, cost: 5.00);
      expect(DiscountPricing.priceOf(loss, _pct('10')).isBelowCost, isFalse);
    });

    test(
      'all products: every unsafe product; selected: only selected ones',
      () {
        final all = DiscountPricing.belowCost(
          products: discountProducts,
          scope: DiscountScope.allProducts,
          selectedProductIds: const {},
          percentage: _pct('10'),
        );
        expect(all.map((item) => item.product.name), ['Loss leader', 'Sugar']);

        final selected = DiscountPricing.belowCost(
          products: discountProducts,
          scope: DiscountScope.selectedProducts,
          selectedProductIds: {'rice', 'sugar'},
          percentage: _pct('10'),
        );
        expect(selected.map((item) => item.product.name), ['Sugar']);
      },
    );
  });

  group('SaveDiscountSettings', () {
    final now = DateTime.utc(2026, 10, 15, 12);

    DiscountSettingsDraft draft({
      bool isEnabled = true,
      DiscountScope scope = DiscountScope.allProducts,
      String percent = '10',
      DateTime? endsAt,
      Set<String> selected = const {},
    }) {
      return DiscountSettingsDraft(
        isEnabled: isEnabled,
        scope: scope,
        percentage: _pct(percent),
        endsAt: endsAt,
        selectedProductIds: selected,
      );
    }

    test(
      'closed release gate: refuses without touching the repository',
      () async {
        final repository = FakeDiscountSettingsRepository();
        final save = SaveDiscountSettings(repository, writesEnabled: false);

        await expectLater(
          save(draft(), current: null, products: discountProducts, now: now),
          _throwsKind(DiscountSettingsErrorKind.writesNotAvailable),
        );
        expect(repository.saves, isEmpty);
      },
    );

    test(
      'all products with unsafe products: allowed (they keep full price)',
      () async {
        final repository = FakeDiscountSettingsRepository();
        await SaveDiscountSettings(repository, writesEnabled: true)(
          draft(),
          current: null,
          products: discountProducts,
          now: now,
        );
        expect(repository.saves, hasLength(1));
      },
    );

    test(
      'selected products with an unsafe product: blocked, enabled or not',
      () async {
        final repository = FakeDiscountSettingsRepository();
        final save = SaveDiscountSettings(repository, writesEnabled: true);
        for (final isEnabled in [true, false]) {
          await expectLater(
            save(
              draft(
                isEnabled: isEnabled,
                scope: DiscountScope.selectedProducts,
                selected: {'rice', 'sugar'},
              ),
              current: null,
              products: discountProducts,
              now: now,
            ),
            _throwsKind(DiscountSettingsErrorKind.unsafeSelection),
          );
        }
        expect(repository.saves, isEmpty);
      },
    );

    test('selected products that are all safe: saved', () async {
      final repository = FakeDiscountSettingsRepository();
      await SaveDiscountSettings(repository, writesEnabled: true)(
        draft(scope: DiscountScope.selectedProducts, selected: {'rice', 'oil'}),
        current: null,
        products: discountProducts,
        now: now,
      );
      expect(repository.saves.single.selectedProductIds, {'rice', 'oil'});
    });

    test('enabling selected products with none selected is refused', () async {
      final repository = FakeDiscountSettingsRepository();
      await expectLater(
        SaveDiscountSettings(repository, writesEnabled: true)(
          draft(scope: DiscountScope.selectedProducts),
          current: null,
          products: discountProducts,
          now: now,
        ),
        _throwsKind(DiscountSettingsErrorKind.noProductsSelected),
      );
    });

    test('enabling with an end date already past is refused', () async {
      final repository = FakeDiscountSettingsRepository();
      await expectLater(
        SaveDiscountSettings(repository, writesEnabled: true)(
          draft(endsAt: now.subtract(const Duration(minutes: 1))),
          current: null,
          products: discountProducts,
          now: now,
        ),
        _throwsKind(DiscountSettingsErrorKind.endDateInPast),
      );
      expect(repository.saves, isEmpty);
    });
  });
}
