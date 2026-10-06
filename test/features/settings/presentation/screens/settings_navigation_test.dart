import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/more/presentation/screens/more_screen.dart';
import 'package:shopmate/features/settings/presentation/screens/settings_screen.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';
import 'package:shopmate/features/shop/domain/entities/shop_profile_update.dart';
import 'package:shopmate/features/shop/domain/repositories/shop_branding_repository.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

class _Repository implements ShopBrandingRepository {
  ShopBrandingResult _result(String shopId) {
    return ShopBrandingResult(
      branding: ShopBranding(shopId: shopId, name: "Danny's Shop"),
    );
  }

  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) async =>
      _result(shopId);

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

Future<GoRouter> _pumpMore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/more',
    routes: [
      GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith(
          (ref) async => const ShopAccess(
            userId: 'user-1',
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            role: 'owner',
          ),
        ),
        shopBrandingRepositoryProvider.overrideWithValue(_Repository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapMoreItem(WidgetTester tester, String title) async {
  final item = find.text(title);
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('More -> Settings opens the Settings screen', (tester) async {
    final router = await _pumpMore(tester);

    await _tapMoreItem(tester, 'Settings');

    expect(router.state.uri.path, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Business Profile'), findsOneWidget);
    expect(find.text("Danny's Shop"), findsOneWidget);
    expect(find.text('Settings is coming soon.'), findsNothing);
  });

  testWidgets('Back from Settings returns to More', (tester) async {
    final router = await _pumpMore(tester);
    await _tapMoreItem(tester, 'Settings');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/more');
    expect(find.byType(MoreScreen), findsOneWidget);
  });

  for (final title in const [
    'Analytics',
    'Users & Permissions',
    'Notifications',
    'Help & Support',
  ]) {
    testWidgets('More -> $title is still "coming soon"', (tester) async {
      final router = await _pumpMore(tester);

      await _tapMoreItem(tester, title);

      expect(find.text('$title is coming soon.'), findsOneWidget);
      expect(router.state.uri.path, '/more');
    });
  }
}
