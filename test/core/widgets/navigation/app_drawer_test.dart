import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/core/widgets/navigation/app_drawer.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';
import 'package:shopmate/features/shop/domain/repositories/shop_branding_repository.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

/// The drawer header reads shop branding; navigation tests use a fixed shop.
class _BrandingRepository implements ShopBrandingRepository {
  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) async {
    return ShopBrandingResult(
      branding: ShopBranding(shopId: shopId, name: 'Test Shop'),
    );
  }

  @override
  Future<ShopBrandingResult> uploadLogo(String shopId, ShopLogoUpload upload) =>
      throw UnimplementedError();

  @override
  Future<ShopBrandingResult> removeLogo(String shopId) =>
      throw UnimplementedError();
}

const _shellRoutes = [
  '/dashboard',
  '/products',
  '/inventory',
  '/sales',
  '/more',
];

const _topLevelRoutes = [
  '/customers',
  '/purchases',
  '/suppliers',
  '/expenses',
  '/reports/business-performance',
  '/reports/inventory',
  '/settings',
];

final _shellScaffoldKey = GlobalKey<ScaffoldState>();

Widget _page(String path) {
  return Scaffold(
    appBar: AppBar(title: Text('Page $path')),
    body: const SizedBox.shrink(),
  );
}

/// Same shape as the app router: tabs in a StatefulShellRoute whose scaffold
/// holds the drawer, and feature routes at the top level outside the shell.
GoRouter _router() {
  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          return Scaffold(
            key: _shellScaffoldKey,
            drawer: const AppDrawer(),
            body: shell,
          );
        },
        branches: [
          for (final path in _shellRoutes)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => Center(child: Text('Tab $path')),
                ),
              ],
            ),
        ],
      ),
      for (final path in _topLevelRoutes)
        GoRoute(path: path, builder: (context, state) => _page(path)),
    ],
  );
}

Future<GoRouter> _pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = _router();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith(
          (ref) async => const ShopAccess(
            userId: 'user-1',
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            shopName: 'Test Shop',
            role: 'owner',
          ),
        ),
        shopBrandingRepositoryProvider.overrideWithValue(_BrandingRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapDrawerItem(WidgetTester tester, String title) async {
  _shellScaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();

  final item = find.descendant(
    of: find.byType(AppDrawer),
    matching: find.text(title),
  );
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    // The drawer header reads the signed-in user. A local placeholder project
    // with no stored session never makes a network request.
    await Supabase.initialize(
      url: 'http://127.0.0.1:1',
      publishableKey: 'test-publishable-key',
    );
  });

  const shellItems = {
    'Dashboard': '/dashboard',
    'Products': '/products',
    'Inventory': '/inventory',
    'Sales': '/sales',
  };

  shellItems.forEach((title, path) {
    testWidgets('$title switches to the $path tab inside the shell', (
      tester,
    ) async {
      final router = await _pumpShell(tester);
      if (path == '/dashboard') {
        router.go('/products');
        await tester.pumpAndSettle();
      }

      await _tapDrawerItem(tester, title);

      expect(router.state.uri.path, path);
      expect(find.text('Tab $path'), findsOneWidget);
      expect(find.byType(AppDrawer), findsNothing);
      // Still inside the shell: nothing to pop back to.
      expect(router.canPop(), isFalse);
    });
  });

  const topLevelItems = {
    'Customers': '/customers',
    'Purchases': '/purchases',
    'Suppliers': '/suppliers',
    'Expenses': '/expenses',
    'Reports': '/reports/business-performance',
    'Inventory Report': '/reports/inventory',
    'Settings': '/settings',
  };

  topLevelItems.forEach((title, path) {
    testWidgets('$title opens $path above the shell; Back returns', (
      tester,
    ) async {
      final router = await _pumpShell(tester);

      await _tapDrawerItem(tester, title);

      expect(router.state.uri.path, path);
      expect(find.text('Page $path'), findsOneWidget);
      expect(router.canPop(), isTrue);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/dashboard');
      expect(find.text('Tab /dashboard'), findsOneWidget);
    });
  });

  testWidgets('Reports and Inventory Report are separate drawer items', (
    tester,
  ) async {
    await _pumpShell(tester);
    _shellScaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    final reports = find.descendant(
      of: find.byType(AppDrawer),
      matching: find.text('Reports'),
    );
    final inventoryReport = find.descendant(
      of: find.byType(AppDrawer),
      matching: find.text('Inventory Report'),
    );
    expect(reports, findsOneWidget);
    expect(inventoryReport, findsOneWidget);
    expect(
      tester.getTopLeft(inventoryReport).dy,
      greaterThan(tester.getTopLeft(reports).dy),
    );
  });

  for (final title in const [
    'Analytics',
    'Users & Permissions',
    'Notifications',
    'Help & Support',
  ]) {
    testWidgets('$title still shows "coming soon" and does not navigate', (
      tester,
    ) async {
      final router = await _pumpShell(tester);

      await _tapDrawerItem(tester, title);

      expect(find.text('$title is coming soon.'), findsOneWidget);
      expect(router.state.uri.path, '/dashboard');
      expect(router.canPop(), isFalse);
    });
  }
}
