import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/sales/presentation/services/receipt_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';
import 'package:shopmate/features/shop/domain/entities/shop_profile_update.dart';
import 'package:shopmate/features/shop/domain/repositories/shop_branding_repository.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

ShopLogoUpload _pngUpload() {
  final bytes = Uint8List(16)
    ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return ShopLogoUpload(bytes: bytes, extension: 'png');
}

/// Records which shop each call was made for; [logoPath] is the stored state.
class _FakeRepository implements ShopBrandingRepository {
  final calls = <String>[];
  String? logoPath;
  String name = 'Shop';
  String? phone;
  ShopBrandingException? failure;

  ShopBrandingResult _result(String shopId) {
    return ShopBrandingResult(
      branding: ShopBranding(
        shopId: shopId,
        name: name,
        phone: phone,
        logoPath: logoPath,
      ),
    );
  }

  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) async {
    calls.add('get:$shopId');
    return _result(shopId);
  }

  @override
  Future<ShopBrandingResult> uploadLogo(
    String shopId,
    ShopLogoUpload upload,
  ) async {
    calls.add('upload:$shopId');
    final error = failure;
    if (error != null) throw error;
    logoPath = '$shopId/logo-1.png';
    return _result(shopId);
  }

  @override
  Future<ShopBrandingResult> removeLogo(String shopId) async {
    calls.add('remove:$shopId');
    final error = failure;
    if (error != null) throw error;
    logoPath = null;
    return _result(shopId);
  }

  @override
  Future<ShopBrandingResult> updateProfile(
    String shopId,
    ShopProfileUpdate update,
  ) async {
    calls.add('profile:$shopId');
    final error = failure;
    if (error != null) throw error;
    name = update.name;
    phone = update.phone;
    return _result(shopId);
  }
}

ProviderContainer _container(
  _FakeRepository repository, {
  ShopAccessStatus status = ShopAccessStatus.active,
  String? shopId = 'shop-1',
}) {
  final container = ProviderContainer(
    overrides: [
      shopAccessProvider.overrideWith(
        (ref) async => ShopAccess(
          userId: 'user-1',
          status: status,
          shopId: shopId,
          shopName: 'Shop',
          role: 'owner',
        ),
      ),
      shopBrandingRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ShopBrandingResult?> _read(ProviderContainer container) async {
  // Resolve shop access first so branding sees the settled shop id.
  await container.read(shopAccessProvider.future);
  return container.read(shopBrandingProvider.future);
}

void main() {
  test('loads branding for the current active shop', () async {
    final repository = _FakeRepository();
    final container = _container(repository);

    final result = await _read(container);

    expect(result?.branding.shopId, 'shop-1');
    expect(repository.calls, ['get:shop-1']);
  });

  test('is null and loads nothing without an active shop', () async {
    for (final status in [
      ShopAccessStatus.pending,
      ShopAccessStatus.suspended,
      ShopAccessStatus.noShop,
    ]) {
      final repository = _FakeRepository();
      final container = _container(repository, status: status);

      expect(await _read(container), isNull, reason: status.name);
      expect(repository.calls, isEmpty, reason: status.name);
    }
  });

  test('is cached for the session across reads', () async {
    final repository = _FakeRepository();
    final container = _container(repository);

    await _read(container);
    await container.read(shopBrandingProvider.future);

    expect(repository.calls, ['get:shop-1']);
  });

  test('upload uses the current shop and publishes the new branding', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    await _read(container);

    final result = await container
        .read(shopBrandingProvider.notifier)
        .uploadLogo(_pngUpload());

    expect(repository.calls, ['get:shop-1', 'upload:shop-1']);
    expect(result.branding.logoPath, 'shop-1/logo-1.png');
    expect(
      container.read(shopBrandingProvider).value?.branding.logoPath,
      'shop-1/logo-1.png',
    );
  });

  test(
    'remove uses the current shop and publishes the cleared branding',
    () async {
      final repository = _FakeRepository()..logoPath = 'shop-1/logo-1.png';
      final container = _container(repository);
      await _read(container);

      await container.read(shopBrandingProvider.notifier).removeLogo();

      expect(repository.calls, ['get:shop-1', 'remove:shop-1']);
      expect(
        container.read(shopBrandingProvider).value?.branding.logoPath,
        isNull,
      );
    },
  );

  test(
    'a failed change rethrows and reloads branding from the source',
    () async {
      final repository = _FakeRepository()
        ..failure = const ShopBrandingException(
          ShopBrandingErrorKind.permissionDenied,
        );
      final container = _container(repository);
      final subscription = container.listen(shopBrandingProvider, (_, _) {});
      addTearDown(subscription.close);
      await _read(container);

      await expectLater(
        container.read(shopBrandingProvider.notifier).uploadLogo(_pngUpload()),
        throwsA(isA<ShopBrandingException>()),
      );
      await container.read(shopBrandingProvider.future);

      expect(repository.calls, ['get:shop-1', 'upload:shop-1', 'get:shop-1']);
    },
  );

  test('profile update uses the current shop and refreshes every consumer '
      'that reads the branding', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    await _read(container);

    await container
        .read(shopBrandingProvider.notifier)
        .updateProfile(
          ShopProfileUpdate(name: '  ABC Mini Mart ', phone: '0241234567'),
        );

    expect(repository.calls, ['get:shop-1', 'profile:shop-1']);
    final published = container.read(shopBrandingProvider).value;
    expect(published?.branding.name, 'ABC Mini Mart');
    expect(published?.branding.phone, '0241234567');

    // Receipts build their branding from the same provider value.
    final receipt = ReceiptBranding.from(branding: published);
    expect(receipt.shopName, 'ABC Mini Mart');
    expect(receipt.phone, '0241234567');
  });

  test('a failed profile update rethrows and reloads', () async {
    final repository = _FakeRepository()
      ..failure = const ShopBrandingException(
        ShopBrandingErrorKind.profileUpdateFailed,
      );
    final container = _container(repository);
    final subscription = container.listen(shopBrandingProvider, (_, _) {});
    addTearDown(subscription.close);
    await _read(container);

    await expectLater(
      container
          .read(shopBrandingProvider.notifier)
          .updateProfile(ShopProfileUpdate(name: 'New Name')),
      throwsA(isA<ShopBrandingException>()),
    );
    final reloaded = await container.read(shopBrandingProvider.future);

    expect(repository.calls, ['get:shop-1', 'profile:shop-1', 'get:shop-1']);
    expect(reloaded?.branding.name, 'Shop');
  });

  test('changes are refused without an active shop', () async {
    final repository = _FakeRepository();
    final container = _container(repository, status: ShopAccessStatus.pending);
    await _read(container);

    expect(
      () => container.read(shopBrandingProvider.notifier).removeLogo(),
      throwsStateError,
    );
    expect(repository.calls, isEmpty);
  });
}
