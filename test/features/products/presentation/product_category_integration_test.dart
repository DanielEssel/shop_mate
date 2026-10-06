import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/product_categories/domain/entities/product_category.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_exception.dart';
import 'package:shopmate/features/product_categories/presentation/providers/product_category_providers.dart';
import 'package:shopmate/features/product_categories/presentation/widgets/product_category_field.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/products/presentation/screens/products_screen.dart';

ProductCategory _category(String id, String name) {
  return ProductCategory(
    id: id,
    shopId: 'shop-1',
    name: name,
    isActive: true,
    createdAt: DateTime.utc(2026, 10, 9),
    updatedAt: DateTime.utc(2026, 10, 9),
  );
}

Product _product(
  String id,
  String name, {
  String? categoryId,
  String? categoryName,
  bool categoryIsActive = true,
}) {
  return Product(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryName,
    categoryIsActive: categoryIsActive,
    costPrice: 1,
    sellingPrice: 2,
    stockQuantity: 10,
    lowStockThreshold: 1,
  );
}

final _activeCategories = [
  _category('c1', 'Beverages'),
  _category('c2', 'Snacks'),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('category field', () {
    Future<List<String?>> pumpField(
      WidgetTester tester, {
      String? selectedId,
      String? currentName,
      bool currentActive = true,
      Object? loadError,
    }) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            activeProductCategoriesProvider.overrideWith((ref) async {
              final error = loadError;
              if (error != null) throw error;
              return _activeCategories;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCategoryField(
                selectedCategoryId: selectedId,
                currentCategoryName: currentName,
                currentCategoryIsActive: currentActive,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return changes;
    }

    testWidgets('offers No category plus active categories', (tester) async {
      final changes = await pumpField(tester);

      expect(find.text('No category'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Beverages').last, findsOneWidget);
      expect(find.text('Snacks').last, findsOneWidget);

      await tester.tap(find.text('Snacks').last);
      await tester.pumpAndSettle();
      expect(changes, ['c2']);
    });

    testWidgets('a product can be cleared back to No category', (tester) async {
      final changes = await pumpField(tester, selectedId: 'c1');

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No category').last);
      await tester.pumpAndSettle();

      expect(changes, [null]);
    });

    testWidgets('keeps a product\'s archived category, labelled', (
      tester,
    ) async {
      await pumpField(
        tester,
        selectedId: 'old',
        currentName: 'Old stock',
        currentActive: false,
      );

      expect(find.text('Old stock (archived)'), findsOneWidget);
    });

    testWidgets('a load failure still allows No category and retry', (
      tester,
    ) async {
      await pumpField(
        tester,
        loadError: const ProductCategoryException(
          ProductCategoryErrorKind.loadFailed,
        ),
      );

      expect(find.text('No category'), findsOneWidget);
      expect(
        find.text('Categories could not be loaded. You can save without one.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Retry loading categories'), findsOneWidget);
    });
  });

  group('products list filter', () {
    Future<void> pumpProducts(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsProvider.overrideWith(
              (ref) async => [
                _product(
                  'p1',
                  'Cola',
                  categoryId: 'c1',
                  categoryName: 'Beverages',
                ),
                _product(
                  'p2',
                  'Chips',
                  categoryId: 'c2',
                  categoryName: 'Snacks',
                ),
                _product('p3', 'Loose nails'),
                _product(
                  'p4',
                  'Old candy',
                  categoryId: 'c9',
                  categoryName: 'Old stock',
                  categoryIsActive: false,
                ),
              ],
            ),
            activeProductCategoriesProvider.overrideWith(
              (ref) async => _activeCategories,
            ),
          ],
          child: const MaterialApp(home: ProductsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> selectChip(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pumpAndSettle();
    }

    testWidgets('chips are All, active categories and No category', (
      tester,
    ) async {
      await pumpProducts(tester);

      for (final label in ['All', 'Beverages', 'Snacks', 'No category']) {
        expect(find.widgetWithText(FilterChip, label), findsOneWidget);
      }
      expect(find.widgetWithText(FilterChip, 'Old stock'), findsNothing);
      expect(find.text('Cola'), findsOneWidget);
      expect(find.text('Old candy'), findsOneWidget);
    });

    testWidgets('filters by a real category id', (tester) async {
      await pumpProducts(tester);

      await selectChip(tester, 'Beverages');

      expect(find.text('Cola'), findsOneWidget);
      expect(find.text('Chips'), findsNothing);
      expect(find.text('Loose nails'), findsNothing);
    });

    testWidgets('No category shows uncategorised products', (tester) async {
      await pumpProducts(tester);

      await selectChip(tester, 'No category');

      expect(find.text('Loose nails'), findsOneWidget);
      expect(find.text('Cola'), findsNothing);
      expect(find.text('Old candy'), findsNothing);
    });

    testWidgets('products show their category or No category', (tester) async {
      await pumpProducts(tester);

      expect(find.text('Beverages'), findsWidgets);
      expect(find.text('Old stock'), findsOneWidget);
      expect(find.text('No category'), findsWidgets);
    });
  });
}
