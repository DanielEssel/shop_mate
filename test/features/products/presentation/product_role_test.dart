import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/product_categories/presentation/providers/product_category_providers.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/domain/repositories/product_repository.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/products/presentation/screens/add_product_screen.dart';
import 'package:shopmate/features/products/presentation/screens/product_details_screen.dart';
import 'package:shopmate/features/products/presentation/screens/product_edit_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../shop/shop_role_fixtures.dart';

const _rice = Product(
  id: 'p1',
  name: 'Rice',
  costPrice: 10,
  sellingPrice: 15,
  stockQuantity: 42,
  lowStockThreshold: 5,
);

/// Records updates; nothing else is used by these screens.
class _ProductRepository implements ProductRepository {
  final updates = <Product>[];

  @override
  Future<Product> updateProduct(Product product) async {
    updates.add(product);
    return product;
  }

  @override
  Future<Product> getProductById(String id) async => _rice;

  @override
  Future<List<Product>> getProducts() async => const [_rice];

  @override
  Future<List<Product>> getLowStockProducts() async => const [];

  @override
  Future<Product> createProduct(Product product) => throw UnimplementedError();

  @override
  Future<void> deleteProduct(String productId) => throw UnimplementedError();

  @override
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String extension,
  }) => throw UnimplementedError();

  @override
  Future<void> updateProductImageUrl(String productId, String imageUrl) =>
      throw UnimplementedError();
}

Future<_ProductRepository> _pump(
  WidgetTester tester,
  String role,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _ProductRepository();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
        routes: [GoRoute(path: 'screen', builder: (_, _) => screen)],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        shopAccessProvider.overrideWith((ref) async => activeAccess(role)),
        productRepositoryProvider.overrideWithValue(repository),
        productByIdProvider.overrideWith((ref, id) async => _rice),
        activeProductCategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/screen');
  await tester.pumpAndSettle();
  return repository;
}

TextField _field(WidgetTester tester, String label) {
  return tester.widget<TextField>(
    find.descendant(
      of: find.widgetWithText(TextFormField, label),
      matching: find.byType(TextField),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('product details', () {
    testWidgets('owner: edit, adjust stock and delete', (tester) async {
      await _pump(
        tester,
        ownerRole,
        const ProductDetailsScreen(productId: 'p1'),
      );

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.text('Adjust Stock'), findsOneWidget);
      expect(find.text('Delete Product'), findsOneWidget);
    });

    testWidgets('owner sees selling price, cost and margin', (tester) async {
      await _pump(
        tester,
        ownerRole,
        const ProductDetailsScreen(productId: 'p1'),
      );

      expect(find.text('Selling Price'), findsOneWidget);
      expect(find.text('Cost Price'), findsOneWidget);
      expect(find.text('GH₵ 10.00'), findsOneWidget);
      expect(find.text('Profit / Unit'), findsOneWidget);
      expect(find.text('GH₵ 5.00'), findsOneWidget);
      expect(find.text('Profit Margin'), findsOneWidget);
    });

    testWidgets('attendant: edit only, no adjust or delete', (tester) async {
      await _pump(
        tester,
        attendantRole,
        const ProductDetailsScreen(productId: 'p1'),
      );

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.text('Adjust Stock'), findsNothing);
      expect(find.text('Delete Product'), findsNothing);
    });

    testWidgets('attendant sees selling price and stock, not cost or margin', (
      tester,
    ) async {
      await _pump(
        tester,
        attendantRole,
        const ProductDetailsScreen(productId: 'p1'),
      );

      expect(find.text('Selling Price'), findsOneWidget);
      expect(find.text('GH₵ 15.00'), findsWidgets);
      expect(find.text('Current Stock'), findsOneWidget);
      expect(find.text('42'), findsWidgets);
      expect(find.text('Cost Price'), findsNothing);
      expect(find.text('GH₵ 10.00'), findsNothing);
      expect(find.text('Profit / Unit'), findsNothing);
      expect(find.text('GH₵ 5.00'), findsNothing);
      expect(find.text('Profit Margin'), findsNothing);
    });
  });

  group('add product', () {
    testWidgets('owner sets opening stock', (tester) async {
      await _pump(tester, ownerRole, const AddProductScreen());

      expect(find.text('Opening Stock *'), findsOneWidget);
      expect(find.text('Selling Price *'), findsOneWidget);
      expect(find.text('Cost Price *'), findsOneWidget);
    });

    testWidgets('attendant sets prices but no opening stock', (tester) async {
      await _pump(tester, attendantRole, const AddProductScreen());

      expect(find.textContaining('Opening Stock'), findsNothing);
      expect(
        find.text('Stock starts at 0. Add stock by recording a purchase.'),
        findsOneWidget,
      );
      expect(find.text('Selling Price *'), findsOneWidget);
      expect(find.text('Cost Price *'), findsOneWidget);
      expect(find.text('Low Stock Alert'), findsOneWidget);
    });
  });

  group('edit product', () {
    testWidgets('owner can edit prices and stock', (tester) async {
      await _pump(tester, ownerRole, const EditProductScreen(product: _rice));

      for (final label in ['Cost Price', 'Selling Price', 'Stock Quantity']) {
        expect(_field(tester, label).enabled, isTrue, reason: label);
      }
      expect(find.text('Only the shop owner can change prices.'), findsNothing);
    });

    testWidgets('attendant sees prices and stock read-only', (tester) async {
      await _pump(
        tester,
        attendantRole,
        const EditProductScreen(product: _rice),
      );

      for (final label in ['Cost Price', 'Selling Price', 'Stock Quantity']) {
        expect(_field(tester, label).enabled, isFalse, reason: label);
      }
      for (final label in ['Product Name', 'SKU', 'Barcode', 'Description']) {
        final field = find.widgetWithText(TextFormField, label);
        if (field.evaluate().isNotEmpty) {
          expect(_field(tester, label).enabled, isTrue, reason: label);
        }
      }
      expect(_field(tester, 'Low Stock Threshold').enabled, isTrue);
      expect(
        find.text('Only the shop owner can change prices.'),
        findsNWidgets(2),
      );
      expect(
        find.text('Stock changes through sales and purchases.'),
        findsOneWidget,
      );
    });

    testWidgets('attendant save keeps the stored prices and stock', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        attendantRole,
        const EditProductScreen(product: _rice),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low Stock Threshold'),
        '8',
      );
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final saved = repository.updates.single;
      expect(saved.sellingPrice, 15);
      expect(saved.costPrice, 10);
      expect(saved.stockQuantity, 42);
      expect(saved.lowStockThreshold, 8);
    });
  });
}
