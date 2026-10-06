import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/core/widgets/navigation/app_drawer.dart';
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
  _Repository({
    this.name = "Danny's Shop",
    this.phone = '0240000001',
    this.logo,
    this.logoFails = false,
  });

  final String name;
  final String? phone;
  final Uint8List? logo;
  final bool logoFails;
  Completer<void>? gate;

  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) async {
    await gate?.future;
    return ShopBrandingResult(
      branding: ShopBranding(
        shopId: shopId,
        name: name,
        phone: phone,
        logoPath: logo == null && !logoFails ? null : '$shopId/logo-1.png',
      ),
      logoBytes: logoFails ? null : logo,
      logoError: logoFails
          ? const ShopBrandingException(ShopBrandingErrorKind.logoUnavailable)
          : null,
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
  ) => throw UnimplementedError();
}

final _scaffoldKey = GlobalKey<ScaffoldState>();

Future<void> _openDrawer(
  WidgetTester tester,
  _Repository repository, {
  String role = 'owner',
  double width = 420,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        shopAccessProvider.overrideWith(
          (ref) async => ShopAccess(
            userId: 'user-1',
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            shopName: 'Access Name',
            role: role,
          ),
        ),
        shopBrandingRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          key: _scaffoldKey,
          drawer: const AppDrawer(),
          body: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  _scaffoldKey.currentState!.openDrawer();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Finder _inDrawer(Finder finder) {
  return find.descendant(of: find.byType(AppDrawer), matching: finder);
}

Finder get _logo =>
    _inDrawer(find.byKey(const ValueKey('shop-logo-mark-image')));
Finder get _fallback =>
    _inDrawer(find.byKey(const ValueKey('shop-logo-mark-fallback')));
Finder get _placeholder =>
    _inDrawer(find.byKey(const ValueKey('shop-logo-mark-loading')));

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    // The drawer header reads the signed-in user's email; a local placeholder
    // project with no session never makes a network request.
    await Supabase.initialize(
      url: 'http://127.0.0.1:1',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('shows the shop name, phone and logo', (tester) async {
    await _openDrawer(tester, _Repository(logo: _pngLogo));

    expect(_inDrawer(find.text("Danny's Shop")), findsOneWidget);
    expect(_inDrawer(find.text('0240000001')), findsOneWidget);
    expect(_logo, findsOneWidget);
    expect(find.bySemanticsLabel("Danny's Shop logo"), findsOneWidget);
    expect(_inDrawer(find.text('ShopMate')), findsNothing);
  });

  testWidgets('falls back to the initial without a logo', (tester) async {
    await _openDrawer(tester, _Repository());

    expect(_logo, findsNothing);
    expect(_fallback, findsOneWidget);
    expect(_inDrawer(find.text('D')), findsOneWidget);
  });

  testWidgets('without a phone the email line is kept', (tester) async {
    await _openDrawer(tester, _Repository(phone: null));

    expect(_inDrawer(find.text('0240000001')), findsNothing);
    expect(_inDrawer(find.text('Business Management')), findsOneWidget);
  });

  testWidgets('while loading the drawer stays usable', (tester) async {
    final repository = _Repository()..gate = Completer<void>();
    await _openDrawer(tester, repository, settle: false);

    expect(_placeholder, findsOneWidget);
    expect(_inDrawer(find.text('Access Name')), findsOneWidget);
    expect(_inDrawer(find.text('Dashboard')), findsOneWidget);
    expect(_inDrawer(find.text('Settings')), findsOneWidget);

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(_inDrawer(find.text("Danny's Shop")), findsOneWidget);
  });

  testWidgets('a failed logo falls back without an error message', (
    tester,
  ) async {
    await _openDrawer(tester, _Repository(logoFails: true));

    expect(_fallback, findsOneWidget);
    expect(_inDrawer(find.text("Danny's Shop")), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(find.textContaining('Storage'), findsNothing);
  });

  testWidgets('a long shop name is truncated without overflow', (tester) async {
    await _openDrawer(
      tester,
      _Repository(
        name: 'The Very Long Wholesale and Retail Provisions Shop ' * 3,
      ),
      width: 320,
    );

    expect(tester.takeException(), isNull);
    final nameText = tester.widget<Text>(
      _inDrawer(find.textContaining('The Very Long')),
    );
    expect(nameText.maxLines, 2);
    expect(nameText.overflow, TextOverflow.ellipsis);
  });

  for (final role in ['owner', 'staff']) {
    testWidgets('$role sees branding with no editing controls', (tester) async {
      await _openDrawer(tester, _Repository(logo: _pngLogo), role: role);

      expect(_logo, findsOneWidget);
      expect(_inDrawer(find.text("Danny's Shop")), findsOneWidget);
      expect(find.text('Change logo'), findsNothing);
      expect(find.text('Remove logo'), findsNothing);
    });
  }
}
