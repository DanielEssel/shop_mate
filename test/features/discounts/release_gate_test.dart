import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/discounts/domain/entities/discount_percentage.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_release_gate.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings_exception.dart';
import 'package:shopmate/features/discounts/presentation/providers/discount_settings_providers.dart';

import 'fake_discount_settings_repository.dart';

void main() {
  test('the release gate is closed in this build', () {
    // Opening it is a release decision: apply the release-gating migration
    // and roll out the discount-aware checkout first (see the gate's docs).
    expect(DiscountReleaseGate.writesEnabled, isFalse);
  });

  test('the app wiring refuses to save while the gate is closed', () async {
    final repository = FakeDiscountSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        discountSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // The default provider, as the app uses it (no gate override).
    expect(container.read(discountWritesEnabledProvider), isFalse);
    final save = container.read(saveDiscountSettingsProvider);

    await expectLater(
      save(
        DiscountSettingsDraft(
          isEnabled: true,
          scope: DiscountScope.allProducts,
          percentage: DiscountPercentage.fromBasisPoints(1000),
          selectedProductIds: const {},
        ),
        products: discountProducts,
        now: DateTime.utc(2026, 10, 15),
      ),
      throwsA(
        isA<DiscountSettingsException>().having(
          (e) => e.kind,
          'kind',
          DiscountSettingsErrorKind.writesNotAvailable,
        ),
      ),
    );
    expect(repository.saves, isEmpty);
  });
}
