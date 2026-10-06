import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/product_categories/presentation/providers/product_category_providers.dart';
import 'package:shopmate/features/product_categories/presentation/screens/product_categories_screen.dart';
import 'package:shopmate/features/settings/presentation/screens/settings_screen.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

Future<void> _pump(WidgetTester tester, {required String role}) async {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'categories',
            builder: (context, state) => const ProductCategoriesScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith(
          (ref) async => ShopAccess(
            userId: 'user-1',
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            role: role,
          ),
        ),
        shopBrandingProvider.overrideWith(_FixedBranding.new),
        productCategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedBranding extends ShopBrandingNotifier {
  @override
  Future<ShopBrandingResult?> build() async {
    return const ShopBrandingResult(
      branding: ShopBranding(shopId: 'shop-1', name: "Danny's Shop"),
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('owner sees Product categories and can open it', (tester) async {
    await _pump(tester, role: 'owner');

    final entry = find.text('Product categories');
    expect(entry, findsOneWidget);

    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(ProductCategoriesScreen), findsOneWidget);
  });

  testWidgets('staff do not see the category management entry', (tester) async {
    await _pump(tester, role: 'staff');

    expect(find.text('Product categories'), findsNothing);
    expect(find.text("Danny's Shop"), findsOneWidget);
  });
}
