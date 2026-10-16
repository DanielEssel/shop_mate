import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings_exception.dart';
import 'package:shopmate/features/discounts/presentation/providers/discount_settings_providers.dart';
import 'package:shopmate/features/discounts/presentation/screens/discount_settings_screen.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../shop/shop_role_fixtures.dart';
import '../fake_discount_settings_repository.dart';

const _desktop = Size(1200, 1800);
const _phone = Size(400, 900);

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeDiscountSettingsRepository repository, {
  String role = ownerRole,
  bool writesEnabled = false,
  List<Product>? products,
  Future<List<Product>> Function()? loadProducts,
  Size size = _desktop,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Settings home')),
      ),
      GoRoute(
        path: '/discounts',
        builder: (_, _) => const DiscountSettingsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        shopAccessProvider.overrideWith((ref) async => activeAccess(role)),
        discountSettingsRepositoryProvider.overrideWithValue(repository),
        discountWritesEnabledProvider.overrideWithValue(writesEnabled),
        productsProvider.overrideWith(
          (ref) =>
              loadProducts?.call() ??
              Future.value(products ?? discountProducts),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/discounts');
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return router;
}

/// Any Material button (Filled, Outlined, Text...) showing [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label)).enabled;

Finder get _percentage => find.byKey(const ValueKey('discount-percentage'));

Finder _segment(String label) => find.descendant(
  of: find.byType(SegmentedButton<DiscountScope>),
  matching: find.text(label),
);

Future<void> _enterPercentage(WidgetTester tester, String value) async {
  await tester.enterText(_percentage, value);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectScope(WidgetTester tester, String label) =>
    _tap(tester, _segment(label));

Finder _productTile(String id) => find.byKey(ValueKey('discount-product-$id'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('access and states', () {
    testWidgets('owner with no discount: empty overview and safe defaults', (
      tester,
    ) async {
      await _pump(tester, FakeDiscountSettingsRepository());

      expect(find.text('Discounts'), findsOne);
      expect(find.text('No discount set up'), findsOne);
      expect(find.textContaining('Sales use normal prices.'), findsWidgets);
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('discount-enabled')),
      );
      expect(toggle.value, isFalse);
      expect(
        tester.widget<TextFormField>(_percentage).controller!.text,
        isEmpty,
      );
      expect(find.text('No end date'), findsOne);
      // Nothing changed yet, so nothing to save.
      expect(_enabled(tester, 'Save discount'), isFalse);
    });

    testWidgets('attendant: no settings, no products, no costs', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository(
        settings: discountSettings(),
      );
      await _pump(tester, repository, role: attendantRole);

      expect(find.text('Only the shop owner can manage discounts.'), findsOne);
      expect(find.byKey(const ValueKey('discount-percentage')), findsNothing);
      expect(find.textContaining('Cost'), findsNothing);
      expect(repository.loads, 0);
    });

    testWidgets('loading shows a placeholder, then the form', (tester) async {
      final repository = FakeDiscountSettingsRepository()
        ..loadGate = Completer<void>();
      await _pump(tester, repository, settle: false);

      expect(_percentage, findsNothing);
      expect(find.text('Save discount'), findsNothing);

      repository.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(_percentage, findsOne);
    });

    testWidgets('a load error is safe and Retry recovers', (tester) async {
      final repository =
          FakeDiscountSettingsRepository(settings: discountSettings())
            ..loadError = const DiscountSettingsException(
              DiscountSettingsErrorKind.loadFailed,
              code: 'XX000',
            );
      await _pump(tester, repository);

      expect(find.text('Unable to load discount settings'), findsOne);
      expect(find.textContaining('XX000'), findsNothing);

      await _tap(tester, _button('Retry'));
      expect(find.text('Saved discount'), findsOne);
      expect(repository.loads, 2);
    });

    testWidgets('existing configuration: overview and a prefilled form', (
      tester,
    ) async {
      final endsAt = DateTime(2030, 1, 21); // end of Jan 20, 2030
      await _pump(
        tester,
        FakeDiscountSettingsRepository(
          settings: discountSettings(
            scope: DiscountScope.selectedProducts,
            basisPoints: 1250,
            endsAt: endsAt,
            selectedProductIds: {'rice', 'oil'},
          ),
        ),
      );

      expect(find.text('Active'), findsOne);
      expect(find.text('12.5%'), findsOne);
      expect(find.text('2 selected products'), findsOne);
      final day = const DefaultMaterialLocalizations().formatMediumDate(
        DateTime(2030, 1, 20),
      );
      expect(find.text('End of $day, 2030'), findsOne);
      expect(
        tester.widget<TextFormField>(_percentage).controller!.text,
        '12.5',
      );
      expect(find.text('Ends at the end of $day, 2030'), findsOne);
      expect(find.text('2 of 6 products selected'), findsOne);
    });

    testWidgets('an ended discount is shown as ended', (tester) async {
      await _pump(
        tester,
        FakeDiscountSettingsRepository(
          settings: discountSettings(endsAt: DateTime.utc(2020)),
        ),
      );
      expect(find.text('Ended'), findsOne);
      expect(find.textContaining('The end date has passed'), findsOne);
    });

    testWidgets('works at phone width', (tester) async {
      await _pump(tester, FakeDiscountSettingsRepository(), size: _phone);
      expect(tester.takeException(), isNull);
      expect(_percentage, findsOne);
    });
  });

  group('percentage', () {
    testWidgets('inline validation for every kind of bad input', (
      tester,
    ) async {
      await _pump(tester, FakeDiscountSettingsRepository());

      final cases = {
        '0': 'The discount must be at least 0.01%.',
        '-5': 'The discount must be at least 0.01%.',
        '100': 'The discount must be below 100%.',
        '10.555': 'Use at most two decimal places.',
        'abc': 'Enter a number such as 10 or 12.5.',
        '': 'Enter a discount percentage.',
      };
      for (final MapEntry(key: input, value: message) in cases.entries) {
        await _enterPercentage(tester, input);
        expect(find.text(message), findsOne, reason: input);
      }
      for (final valid in ['0.01', '99.99']) {
        await _enterPercentage(tester, valid);
        expect(find.textContaining('The discount must'), findsNothing);
        expect(find.textContaining('decimal places'), findsNothing);
      }
    });
  });

  group('scope and products', () {
    testWidgets('select, deselect and keep the selection across scopes', (
      tester,
    ) async {
      await _pump(tester, FakeDiscountSettingsRepository());

      await _selectScope(tester, 'Selected products');
      expect(find.text('0 of 6 products selected'), findsOne);

      await _tap(tester, _productTile('rice'));
      await _tap(tester, _productTile('oil'));
      expect(find.text('2 of 6 products selected'), findsOne);

      await _tap(tester, _productTile('oil'));
      expect(find.text('1 of 6 products selected'), findsOne);

      await _selectScope(tester, 'All products');
      expect(_productTile('rice'), findsNothing);
      await _selectScope(tester, 'Selected products');
      expect(find.text('1 of 6 products selected'), findsOne);
      expect(
        tester.widget<CheckboxListTile>(_productTile('rice')).value,
        isTrue,
      );
    });

    testWidgets('search filters locally; no match shows a message', (
      tester,
    ) async {
      var loads = 0;
      await _pump(
        tester,
        FakeDiscountSettingsRepository(),
        loadProducts: () async {
          loads++;
          return discountProducts;
        },
      );
      await _selectScope(tester, 'Selected products');

      final search = find
          .descendant(
            of: find.byType(TextField),
            matching: find.byWidgetPredicate(
              (widget) => widget is EditableText,
            ),
          )
          .last;
      await tester.enterText(search, 'oil');
      await tester.pumpAndSettle();
      expect(_productTile('oil'), findsOne);
      expect(_productTile('rice'), findsNothing);

      await tester.enterText(search, 'RC-1'); // by SKU
      await tester.pumpAndSettle();
      expect(_productTile('rice'), findsOne);

      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching products'), findsOne);
      expect(loads, 1, reason: 'searching never refetches products');
    });

    testWidgets('no active products: a clear empty state', (tester) async {
      await _pump(tester, FakeDiscountSettingsRepository(), products: []);
      await _selectScope(tester, 'Selected products');
      expect(find.text('No active products'), findsOne);
    });
  });

  group('below cost', () {
    testWidgets('all products: unsafe products listed with prices and cost', (
      tester,
    ) async {
      await _pump(tester, FakeDiscountSettingsRepository());
      await _enterPercentage(tester, '10');

      expect(find.text('2 products would sell below cost'), findsOne);
      expect(
        find.textContaining('They keep their normal price and get no discount'),
        findsOne,
      );
      expect(
        find.text('GHS 7.00 → GHS 6.30 · Cost GHS 6.80 · GHS 0.50 below cost'),
        findsOne,
      );
      expect(
        find.text('GHS 4.00 → GHS 3.60 · Cost GHS 5.00 · GHS 1.40 below cost'),
        findsOne,
      );
    });

    testWidgets('selected products: only unsafe SELECTED products, blocking', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository();
      await _pump(tester, repository, writesEnabled: true);
      await _enterPercentage(tester, '10');
      await _selectScope(tester, 'Selected products');
      expect(find.textContaining('below cost'), findsNothing);

      await _tap(tester, _productTile('rice'));
      expect(find.textContaining('below cost'), findsNothing);
      await _tap(tester, _productTile('sugar'));
      expect(find.text('1 selected product would sell below cost'), findsOne);
      expect(find.textContaining('Remove or reprice it'), findsOne);

      await _tap(tester, _button('Save discount'));
      expect(
        find.text(DiscountSettingsErrorKind.unsafeSelection.message),
        findsOne,
      );
      expect(repository.saves, isEmpty);

      // Removing it clears the block.
      await _tap(tester, _productTile('sugar'));
      expect(find.textContaining('below cost'), findsNothing);
    });

    testWidgets('warnings follow the percentage', (tester) async {
      await _pump(tester, FakeDiscountSettingsRepository());
      await _enterPercentage(tester, '2');
      // Sugar: 7.00 - 0.14 = 6.86 >= 6.80; only the loss leader remains.
      expect(find.text('1 product would sell below cost'), findsOne);
      await _enterPercentage(tester, '3');
      // Sugar: 7.00 - 0.21 = 6.79 < 6.80.
      expect(find.text('2 products would sell below cost'), findsOne);
    });
  });

  group('end date', () {
    testWidgets('set an end date, then remove it', (tester) async {
      await _pump(tester, FakeDiscountSettingsRepository());

      await _tap(tester, _button('Set end date'));
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final day = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 3));
      final typed =
          '${day.month.toString().padLeft(2, '0')}/'
          '${day.day.toString().padLeft(2, '0')}/${day.year}';
      await tester.enterText(find.byType(TextField).last, typed);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final label = const DefaultMaterialLocalizations().formatMediumDate(day);
      expect(find.text('Ends at the end of $label, ${day.year}'), findsOne);

      await _tap(tester, find.byTooltip('Remove end date'));
      expect(find.text('No end date'), findsOne);
    });
  });

  group('saving', () {
    testWidgets('closed release gate: a clear message and no write', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository();
      await _pump(tester, repository);

      expect(find.byKey(const ValueKey('discount-gate-notice')), findsOne);
      await _enterPercentage(tester, '10');
      await _tap(tester, _button('Save discount'));

      expect(
        find.text(DiscountSettingsErrorKind.writesNotAvailable.message),
        findsOne,
      );
      expect(repository.saves, isEmpty);
      expect(find.text('Discount settings saved.'), findsNothing);
      // The change is still there to save later.
      expect(_enabled(tester, 'Save discount'), isTrue);
    });

    testWidgets('open gate: saves exactly what was entered', (tester) async {
      final repository = FakeDiscountSettingsRepository();
      await _pump(tester, repository, writesEnabled: true);

      expect(find.byKey(const ValueKey('discount-gate-notice')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('discount-enabled')));
      await _enterPercentage(tester, '12.5');
      await _selectScope(tester, 'Selected products');
      await _tap(tester, _productTile('rice'));
      await _tap(tester, _button('Save discount'));

      final saved = repository.saves.single;
      expect(saved.isEnabled, isTrue);
      expect(saved.percentage.databaseValue, '12.50');
      expect(saved.scope, DiscountScope.selectedProducts);
      expect(saved.selectedProductIds, {'rice'});
      expect(saved.endsAt, isNull);
      expect(find.text('Discount settings saved.'), findsOne);
      // Saved: nothing left to save, and the overview shows it.
      expect(_enabled(tester, 'Save discount'), isFalse);
      expect(find.text('Saved discount'), findsOne);
    });

    testWidgets('saved settings are there after leaving and reopening', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository();
      final router = await _pump(tester, repository, writesEnabled: true);
      await _tap(tester, find.byKey(const ValueKey('discount-enabled')));
      await _enterPercentage(tester, '12.5');
      await _selectScope(tester, 'Selected products');
      await _tap(tester, _productTile('rice'));
      await _tap(tester, _productTile('oil'));
      await _tap(tester, _button('Save discount'));
      final loadsAfterSave = repository.loads;

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Settings home'), findsOne);
      router.push('/discounts');
      await tester.pumpAndSettle();

      expect(repository.loads, greaterThan(loadsAfterSave));
      expect(find.text('Active'), findsOne);
      expect(find.text('12.5%'), findsOne);
      expect(
        tester.widget<TextFormField>(_percentage).controller!.text,
        '12.5',
      );
      expect(find.text('2 of 6 products selected'), findsOne);
      expect(_enabled(tester, 'Save discount'), isFalse);
    });

    testWidgets('an active discount can be switched off and stays off', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository(
        settings: discountSettings(),
      );
      final router = await _pump(tester, repository, writesEnabled: true);
      expect(find.text('Active'), findsOne);

      await _tap(tester, find.byKey(const ValueKey('discount-enabled')));
      await _tap(tester, _button('Save discount'));

      final saved = repository.saves.single;
      expect(saved.isEnabled, isFalse);
      expect(saved.percentage.databaseValue, '10.00');
      expect(find.text('Discount settings saved.'), findsOne);

      router.pop();
      await tester.pumpAndSettle();
      router.push('/discounts');
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsNothing);
      expect(tester.widget<TextFormField>(_percentage).controller!.text, '10');
    });

    for (final kind in [
      DiscountSettingsErrorKind.unsafeSelection,
      DiscountSettingsErrorKind.endDateInPast,
      DiscountSettingsErrorKind.writesNotAvailable,
    ]) {
      testWidgets('the database refusing (${kind.name}): its message, '
          'nothing claimed as saved', (tester) async {
        final repository = FakeDiscountSettingsRepository()
          ..saveError = DiscountSettingsException(kind);
        await _pump(tester, repository, writesEnabled: true);
        await _enterPercentage(tester, '10');
        await _tap(tester, _button('Save discount'));

        expect(find.text(kind.message), findsOne);
        expect(find.text('Discount settings saved.'), findsNothing);
        expect(_enabled(tester, 'Save discount'), isTrue);
      });
    }

    testWidgets('one submission while saving', (tester) async {
      final repository = FakeDiscountSettingsRepository()
        ..saveGate = Completer<void>();
      await _pump(tester, repository, writesEnabled: true);
      await _enterPercentage(tester, '10');

      await tester.ensureVisible(_button('Save discount'));
      await tester.tap(_button('Save discount'));
      await tester.pump();
      expect(find.text('Saving...'), findsOne);
      await tester.tap(find.text('Saving...'), warnIfMissed: false);
      await tester.pump();

      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(repository.saves, hasLength(1));
    });

    testWidgets('permission denied: a clear message and no false success', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository()
        ..saveError = const DiscountSettingsException(
          DiscountSettingsErrorKind.permissionDenied,
          code: '42501',
        );
      await _pump(tester, repository, writesEnabled: true);
      await _enterPercentage(tester, '10');
      await _tap(tester, _button('Save discount'));

      expect(
        find.text(DiscountSettingsErrorKind.permissionDenied.message),
        findsOne,
      );
      expect(find.text('Discount settings saved.'), findsNothing);
      expect(find.text('No discount set up'), findsOne);
      expect(_enabled(tester, 'Save discount'), isTrue);
      expect(repository.saves, hasLength(1), reason: 'no automatic retry');
    });

    testWidgets('network failure: its own message, changes kept', (
      tester,
    ) async {
      final repository = FakeDiscountSettingsRepository()
        ..saveError = const DiscountSettingsException(
          DiscountSettingsErrorKind.network,
        );
      await _pump(tester, repository, writesEnabled: true);
      await _enterPercentage(tester, '10');
      await _tap(tester, _button('Save discount'));

      expect(find.text(DiscountSettingsErrorKind.network.message), findsOne);
      expect(tester.widget<TextFormField>(_percentage).controller!.text, '10');
    });

    testWidgets('invalid input is never sent', (tester) async {
      final repository = FakeDiscountSettingsRepository();
      await _pump(tester, repository, writesEnabled: true);
      await _enterPercentage(tester, '150');
      await _tap(tester, _button('Save discount'));

      expect(find.text('The discount must be below 100%.'), findsOne);
      expect(repository.saves, isEmpty);
    });
  });

  group('unsaved changes', () {
    testWidgets('leaving with changes asks first', (tester) async {
      await _pump(tester, FakeDiscountSettingsRepository());
      await _enterPercentage(tester, '10');

      await _tap(tester, find.byTooltip('Back'));
      expect(find.text('Discard changes?'), findsOne);
      await _tap(tester, _button('Keep editing'));
      expect(_percentage, findsOne);

      await _tap(tester, find.byTooltip('Back'));
      await _tap(tester, _button('Discard'));
      expect(find.text('Settings home'), findsOne);
    });

    testWidgets('Discard changes restores what was loaded', (tester) async {
      await _pump(
        tester,
        FakeDiscountSettingsRepository(settings: discountSettings()),
      );
      await _enterPercentage(tester, '25');
      await _tap(tester, _button('Discard changes'));

      expect(tester.widget<TextFormField>(_percentage).controller!.text, '10');
      expect(_enabled(tester, 'Save discount'), isFalse);
    });

    testWidgets('leaving without changes does not ask', (tester) async {
      await _pump(tester, FakeDiscountSettingsRepository());
      await _tap(tester, find.byTooltip('Back'));
      expect(find.text('Settings home'), findsOne);
    });
  });
}
