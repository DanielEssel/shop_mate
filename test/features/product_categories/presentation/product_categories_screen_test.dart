import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/product_categories/domain/entities/product_category.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_exception.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_name.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_summary.dart';
import 'package:shopmate/features/product_categories/domain/repositories/product_category_repository.dart';
import 'package:shopmate/features/product_categories/presentation/providers/product_category_providers.dart';
import 'package:shopmate/features/product_categories/presentation/screens/product_categories_screen.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

ProductCategory _category(String id, String name, {bool active = true}) {
  return ProductCategory(
    id: id,
    shopId: 'shop-1',
    name: name,
    isActive: active,
    createdAt: DateTime.utc(2026, 10, 9),
    updatedAt: DateTime.utc(2026, 10, 9),
  );
}

/// In-memory repository with controllable failures.
class _FakeRepository implements ProductCategoryRepository {
  _FakeRepository(List<ProductCategory> initial, {Map<String, int>? counts})
    : categories = [...initial],
      counts = counts ?? {};

  final List<ProductCategory> categories;
  final Map<String, int> counts;
  final calls = <String>[];
  Completer<void>? loadGate;
  ProductCategoryException? loadFailure;
  ProductCategoryException? writeFailure;
  int _nextId = 1;

  @override
  Future<List<ProductCategorySummary>> getCategories() async {
    calls.add('list');
    await loadGate?.future;
    final failure = loadFailure;
    if (failure != null) throw failure;
    final sorted = [...categories]..sort((a, b) => a.name.compareTo(b.name));
    return [
      for (final category in sorted)
        ProductCategorySummary(
          category: category,
          activeProductCount: counts[category.id] ?? 0,
        ),
    ];
  }

  @override
  Future<List<ProductCategory>> getActiveCategories() async =>
      categories.where((c) => c.isActive).toList();

  @override
  Future<ProductCategory> createCategory(ProductCategoryName name) async {
    calls.add('create:${name.value}');
    final failure = writeFailure;
    if (failure != null) throw failure;
    final created = _category('new-${_nextId++}', name.value);
    categories.add(created);
    return created;
  }

  @override
  Future<ProductCategory> renameCategory(
    String id,
    ProductCategoryName name,
  ) async {
    calls.add('rename:$id:${name.value}');
    final failure = writeFailure;
    if (failure != null) throw failure;
    final index = categories.indexWhere((c) => c.id == id);
    final renamed = _category(
      id,
      name.value,
      active: categories[index].isActive,
    );
    categories[index] = renamed;
    return renamed;
  }

  @override
  Future<ProductCategory> setCategoryActive(
    String id, {
    required bool isActive,
  }) async {
    calls.add('${isActive ? 'restore' : 'archive'}:$id');
    final failure = writeFailure;
    if (failure != null) throw failure;
    final index = categories.indexWhere((c) => c.id == id);
    final updated = _category(id, categories[index].name, active: isActive);
    categories[index] = updated;
    return updated;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository, {
  String role = 'owner',
  bool settle = true,
  Size size = const Size(420, 1600),
}) async {
  tester.view.physicalSize = size;
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
            role: role,
          ),
        ),
        productCategoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: ProductCategoriesScreen()),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _enterName(WidgetTester tester, String name) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    ),
    name,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

Future<void> _menuAction(
  WidgetTester tester,
  String category,
  String action,
) async {
  await tester.tap(find.byTooltip('Actions for $category'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('lists active categories with product counts', (tester) async {
    await _pump(
      tester,
      _FakeRepository(
        [
          _category('c1', 'Beverages'),
          _category('c2', 'Snacks'),
          _category('c3', 'Old stock', active: false),
        ],
        counts: {'c1': 2, 'c2': 1},
      ),
    );

    expect(find.text('Beverages'), findsOneWidget);
    expect(find.text('2 products'), findsOneWidget);
    expect(find.text('1 product'), findsOneWidget);
    expect(find.text('Old stock'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Old stock'), findsOneWidget);
    expect(find.text('0 products · Archived'), findsOneWidget);
  });

  testWidgets('shows a loading state', (tester) async {
    final repository = _FakeRepository([])..loadGate = Completer<void>();
    await _pump(tester, repository, settle: false);
    await tester.pump();

    // A loading placeholder announced as such.
    expect(find.bySemanticsLabel('Loading categories'), findsOneWidget);
    expect(find.text('No categories yet'), findsNothing);

    repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);
  });

  testWidgets('empty states for owner and archived view', (tester) async {
    await _pump(tester, _FakeRepository([]));

    expect(find.text('No categories yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New category'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilterChip, 'Archived'));
    await tester.pumpAndSettle();
    expect(find.text('No archived categories'), findsOneWidget);
  });

  testWidgets('load failure shows a safe message and retries', (tester) async {
    final repository = _FakeRepository([_category('c1', 'Beverages')])
      ..loadFailure = const ProductCategoryException(
        ProductCategoryErrorKind.loadFailed,
        cause: 'PGRST raw text',
      );
    await _pump(tester, repository);

    expect(find.text('Unable to load categories'), findsOneWidget);
    expect(find.textContaining('PGRST'), findsNothing);

    repository.loadFailure = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Beverages'), findsOneWidget);
  });

  testWidgets('owner creates a category with a trimmed name', (tester) async {
    final repository = _FakeRepository([]);
    await _pump(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'New category').first);
    await tester.pumpAndSettle();
    await _enterName(tester, '  Drinks  ');

    expect(repository.calls, contains('create:Drinks'));
    expect(find.text('Category created.'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
  });

  testWidgets('an empty name is rejected in the dialog', (tester) async {
    final repository = _FakeRepository([]);
    await _pump(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'New category').first);
    await tester.pumpAndSettle();
    await _enterName(tester, '   ');

    expect(
      find.text('Category name must be 1 to 60 characters.'),
      findsOneWidget,
    );
    expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
  });

  testWidgets('the name field counts toward the existing 60 limit', (
    tester,
  ) async {
    final repository = _FakeRepository([]);
    await _pump(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'New category').first);
    await tester.pumpAndSettle();
    expect(find.text('0 / 60'), findsOneWidget);

    // Counted as the validator counts: trimmed.
    await tester.enterText(find.byType(TextFormField), '  Drinks  ');
    await tester.pump();
    expect(find.text('6 / 60'), findsOneWidget);

    // Typing is not capped; an over-long name is still rejected as before.
    final long = 'A' * 61;
    await tester.enterText(find.byType(TextFormField), long);
    await tester.pump();
    expect(find.text('61 / 60'), findsOneWidget);
    expect(find.text(long), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Category name must be 1 to 60 characters.'),
      findsOneWidget,
    );
    expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
  });

  testWidgets('a duplicate active name gets a clear message', (tester) async {
    final repository = _FakeRepository([_category('c1', 'Drinks')])
      ..writeFailure = const ProductCategoryException(
        ProductCategoryErrorKind.duplicateName,
      );
    await _pump(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'New category'));
    await tester.pumpAndSettle();
    await _enterName(tester, 'drinks');

    expect(
      find.text('An active category with this name already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('owner renames a category', (tester) async {
    final repository = _FakeRepository([_category('c1', 'Drinks')]);
    await _pump(tester, repository);

    await _menuAction(tester, 'Drinks', 'Rename');
    await _enterName(tester, 'Soft drinks');

    expect(repository.calls, contains('rename:c1:Soft drinks'));
    expect(find.text('Category renamed.'), findsOneWidget);
    expect(find.text('Soft drinks'), findsOneWidget);
  });

  testWidgets('archive asks first; Cancel does nothing', (tester) async {
    final repository = _FakeRepository([_category('c1', 'Drinks')]);
    await _pump(tester, repository);

    await _menuAction(tester, 'Drinks', 'Archive');
    expect(find.text('Archive Drinks?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls.where((c) => c.startsWith('archive')), isEmpty);
    expect(find.text('Drinks'), findsOneWidget);
  });

  testWidgets('archive and restore move the category between views', (
    tester,
  ) async {
    final repository = _FakeRepository([_category('c1', 'Drinks')]);
    await _pump(tester, repository);

    await _menuAction(tester, 'Drinks', 'Archive');
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('archive:c1'));
    expect(find.text('Category archived.'), findsOneWidget);
    expect(find.text('Drinks'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Archived'));
    await tester.pumpAndSettle();
    await _menuAction(tester, 'Drinks', 'Restore');

    expect(repository.calls, contains('restore:c1'));
    expect(find.text('Category restored.'), findsOneWidget);
  });

  testWidgets('search filters and offers to clear', (tester) async {
    await _pump(
      tester,
      _FakeRepository([
        _category('c1', 'Beverages'),
        _category('c2', 'Snacks'),
      ]),
    );

    await tester.enterText(find.byType(TextField).first, ' SNA');
    await tester.pumpAndSettle();
    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('Beverages'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No categories found'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Beverages'), findsOneWidget);
  });

  testWidgets('staff see a read-only list', (tester) async {
    await _pump(
      tester,
      _FakeRepository([_category('c1', 'Drinks')]),
      role: 'staff',
    );

    expect(find.text('Drinks'), findsOneWidget);
    expect(
      find.text('Only the shop owner can manage categories.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'New category'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('a backend permission rejection is explained', (tester) async {
    final repository = _FakeRepository([])
      ..writeFailure = const ProductCategoryException(
        ProductCategoryErrorKind.permissionDenied,
      );
    await _pump(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'New category').first);
    await tester.pumpAndSettle();
    await _enterName(tester, 'Drinks');

    expect(
      find.text('Only the shop owner can manage categories.'),
      findsOneWidget,
    );
  });

  group('layout', () {
    const longName =
        'Fresh Farm Produce, Tubers & Plantain from the Kumasi Market';

    for (final role in ['owner', 'staff']) {
      for (final (label, size) in [
        ('320px', const Size(320, 1600)),
        ('desktop', const Size(1440, 1200)),
      ]) {
        testWidgets('$role list fits at $label', (tester) async {
          await _pump(
            tester,
            _FakeRepository(
              [_category('c1', longName), _category('c2', 'Snacks')],
              counts: {'c1': 12},
            ),
            role: role,
            size: size,
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Product Categories'), findsOneWidget);
          expect(find.text(longName), findsOneWidget);
          expect(
            find.byType(PopupMenuButton<String>),
            role == 'owner' ? findsNWidgets(2) : findsNothing,
          );
          expect(
            find.widgetWithText(FilledButton, 'New category'),
            role == 'owner' ? findsOneWidget : findsNothing,
          );
        });
      }
    }

    testWidgets('desktop shows a table with status badges', (tester) async {
      await _pump(
        tester,
        _FakeRepository([_category('c1', 'Drinks')], counts: {'c1': 3}),
        size: const Size(1440, 1200),
      );

      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('3 products'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
    });

    testWidgets('the name dialog fits at 320px', (tester) async {
      await _pump(tester, _FakeRepository([]), size: const Size(320, 700));

      await tester.tap(find.widgetWithText(FilledButton, 'New category').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0 / 60').hitTestable(), findsOne);
      expect(find.widgetWithText(FilledButton, 'Save').hitTestable(), findsOne);
    });
  });
}
