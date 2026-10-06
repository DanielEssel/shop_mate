import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';
import 'package:shopmate/features/shop/domain/entities/shop_profile_update.dart';
import 'package:shopmate/features/shop/domain/repositories/shop_branding_repository.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

final _pngLogo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _Repository implements ShopBrandingRepository {
  _Repository({this.name = "Danny's Shop", this.logo});

  String name;
  final Uint8List? logo;
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) async {
    await gate?.future;
    if (fail) {
      throw const ShopBrandingException(ShopBrandingErrorKind.unavailable);
    }
    return ShopBrandingResult(
      branding: ShopBranding(
        shopId: shopId,
        name: name,
        logoPath: logo == null ? null : '$shopId/logo-1.png',
      ),
      logoBytes: logo,
    );
  }

  @override
  Future<ShopBrandingResult> uploadLogo(String shopId, ShopLogoUpload upload) =>
      throw UnimplementedError();

  @override
  Future<ShopBrandingResult> removeLogo(String shopId) =>
      throw UnimplementedError();

  @override
  Future<ShopBrandingResult> updateProfile(
    String shopId,
    ShopProfileUpdate update,
  ) async {
    name = update.name;
    return getShopBranding(shopId);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  double width = 420,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        shopAccessProvider.overrideWith(
          (ref) async => const ShopAccess(
            userId: 'user-1',
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            shopName: 'Access Name',
            role: 'staff',
          ),
        ),
        shopBrandingRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: DashboardHeader()),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Finder get _logo => find.byKey(const ValueKey('shop-logo-mark-image'));
Finder get _fallback => find.byKey(const ValueKey('shop-logo-mark-fallback'));
Finder get _placeholder => find.byKey(const ValueKey('shop-logo-mark-loading'));
Finder get _shopName => find.byKey(const ValueKey('dashboard-shop-name'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows the shop name and logo', (tester) async {
    await _pump(tester, _Repository(logo: _pngLogo));

    expect(tester.widget<Text>(_shopName).data, "Danny's Shop");
    expect(_logo, findsOneWidget);
    expect(find.bySemanticsLabel("Danny's Shop logo"), findsOneWidget);
  });

  testWidgets('falls back to the initial without a logo', (tester) async {
    await _pump(tester, _Repository());

    expect(_logo, findsNothing);
    expect(_fallback, findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('loading branding does not block the header', (tester) async {
    final repository = _Repository()..gate = Completer<void>();
    await _pump(tester, repository, settle: false);
    await tester.pump();
    await tester.pump();

    expect(_placeholder, findsOneWidget);
    expect(tester.widget<Text>(_shopName).data, 'Access Name');
    expect(
      find.text('Here is what is happening in your shop today.'),
      findsOneWidget,
    );

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_shopName).data, "Danny's Shop");
  });

  testWidgets('a branding failure keeps the header working', (tester) async {
    await _pump(tester, _Repository()..fail = true);

    expect(tester.widget<Text>(_shopName).data, 'Access Name');
    expect(_fallback, findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(find.byTooltip('Open menu'), findsOneWidget);
  });

  testWidgets('a saved business name flows into the header', (tester) async {
    await _pump(tester, _Repository());
    expect(tester.widget<Text>(_shopName).data, "Danny's Shop");

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardHeader)),
    );
    await container
        .read(shopBrandingProvider.notifier)
        .updateProfile(ShopProfileUpdate(name: 'ABC Mini Mart'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(_shopName).data, 'ABC Mini Mart');
  });

  testWidgets('a long shop name is truncated without overflow', (tester) async {
    await _pump(
      tester,
      _Repository(
        name: 'The Very Long Wholesale and Retail Provisions Shop ' * 3,
      ),
      width: 320,
    );

    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(_shopName).overflow, TextOverflow.ellipsis);
    expect(tester.widget<Text>(_shopName).maxLines, 1);
  });
}
