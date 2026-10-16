import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/theme/app_theme.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings_exception.dart';
import 'package:shopmate/features/discounts/presentation/providers/discount_settings_providers.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/sales/domain/entities/pending_sale_request.dart';
import 'package:shopmate/features/sales/domain/entities/sale_request_exception.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/sales/presentation/screens/new_sale_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../discounts/fake_discount_settings_repository.dart';
import '../../../shop/shop_role_fixtures.dart';
import '../../fake_sale_repository.dart';

const _rice = Product(
  id: 'rice',
  name: 'Rice',
  costPrice: 6.00,
  sellingPrice: 10.00,
  stockQuantity: 50,
  lowStockThreshold: 2,
);
const _sugar = Product(
  id: 'sugar',
  name: 'Sugar',
  costPrice: 6.80,
  sellingPrice: 7.00,
  stockQuantity: 50,
  lowStockThreshold: 2,
);
const _oil = Product(
  id: 'oil',
  name: 'Oil',
  costPrice: 5.00,
  sellingPrice: 19.99,
  stockQuantity: 50,
  lowStockThreshold: 2,
);

const _ama = Customer(id: 'c-ama', name: 'Ama Mensah', phone: '0241234567');

const _refusedMessage =
    'Discount could not be applied to one or more selected products. Review '
    'the discount settings or remove the affected product before trying '
    'again.';

/// Answers with what the "database" recorded (by default the discounted
/// estimate the tests expect).
class _Repository extends FakeSaleRepository {
  _Repository() {
    totalFor = (_) => recordedTotal;
    recordedDiscount = 1.00;
  }

  double recordedTotal = 9.00;

  /// The request sent to the database (one per call).
  SaleDraft draftAt(int index) => submissions[index].draft;
}

class _Customers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => const [_ama];
}

const _desktop = Size(1280, 1100);

Future<(_Repository, GoRouter)> _pump(
  WidgetTester tester, {
  DiscountSettings? settings,
  Object? settingsError,
  Size size = _desktop,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final createSale = _Repository();
  final router = GoRouter(
    initialLocation: '/sales/new',
    routes: [
      GoRoute(
        path: '/sales',
        builder: (_, _) => const Scaffold(body: Text('Sales list')),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const NewSaleScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Scaffold(body: Text('Sale ${state.pathParameters['id']}')),
            routes: [
              GoRoute(
                path: 'receipt',
                builder: (_, state) => Scaffold(
                  body: Text('Receipt ${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        salesProductsProvider.overrideWith(
          (ref) async => [_rice, _sugar, _oil],
        ),
        customersProvider.overrideWith(_Customers.new),
        salesRepositoryProvider.overrideWithValue(createSale),
        pendingSaleStoreProvider.overrideWithValue(InMemoryPendingSaleStore()),
        shopAccessProvider.overrideWith((ref) async => activeAccess(ownerRole)),
        salesProvider.overrideWith((ref) async => const []),
        discountSettingsProvider.overrideWith((ref) async {
          final error = settingsError;
          if (error != null) throw error;
          return settings;
        }),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (createSale, router);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _add(WidgetTester tester, String name) async {
  final addButton = find.byTooltip('Add $name');
  await _tapVisible(
    tester,
    addButton.evaluate().isNotEmpty ? addButton : find.text(name).first,
  );
}

Future<void> _enterAmount(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _complete(WidgetTester tester) async {
  final button = find.text('Complete Sale');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _closeDialog(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _chooseCustomerAndCredit(WidgetTester tester) async {
  await _tapVisible(tester, find.byType(DropdownButtonFormField<String?>));
  await tester.tap(find.text('Ama Mensah • 0241234567').last);
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text('Credit').last);
}

Finder get _completeButton => find.ancestor(
  of: find.text('Complete Sale'),
  matching: find.byType(FilledButton),
);

/// No cost or margin figure may appear at checkout.
void _expectNoCost() {
  expect(find.textContaining('Cost'), findsNothing);
  // The costs of the products used here (as amounts, not substrings of
  // other amounts such as GHS 16.00).
  expect(find.textContaining('GHS 6.80'), findsNothing);
  expect(find.textContaining('GHS 6.00'), findsNothing);
  expect(find.textContaining('GHS 5.00'), findsNothing);
  expect(find.textContaining('margin'), findsNothing);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime.now();
  final allTen = discountSettings();
  final selectedOil = discountSettings(
    scope: DiscountScope.selectedProducts,
    selectedProductIds: {'oil'},
  );
  final selectedSugar = discountSettings(
    scope: DiscountScope.selectedProducts,
    selectedProductIds: {'sugar'},
  );

  group('preview', () {
    testWidgets('all products: original, discount and expected price', (
      tester,
    ) async {
      await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _add(tester, 'Oil');

      expect(find.text('GHS 9.00 each · was GHS 10.00, 10% off'), findsOne);
      // 19.99 at 10%: 1.999 rounds to 2.00 -> 17.99.
      expect(find.text('GHS 17.99 each · was GHS 19.99, 10% off'), findsOne);
      expect(find.text('Subtotal'), findsOne);
      expect(find.text('GHS 29.99'), findsOne);
      expect(find.text('-GHS 3.00'), findsOne);
      expect(find.text('GHS 26.99'), findsWidgets);
      expect(
        find.textContaining('confirmed when the sale is recorded'),
        findsOne,
      );
      _expectNoCost();
    });

    testWidgets('all products: a cost-protected product keeps its price', (
      tester,
    ) async {
      await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _add(tester, 'Sugar');

      expect(find.text('GHS 7.00 each'), findsOne); // Sugar: no discount
      expect(find.textContaining('was GHS 7.00'), findsNothing);
      expect(find.text('-GHS 1.00'), findsOne); // Rice only
      expect(find.text('GHS 16.00'), findsWidgets);
      expect(find.textContaining('may be refused'), findsNothing);
      _expectNoCost();
    });

    testWidgets('selected products: only selected products are discounted', (
      tester,
    ) async {
      await _pump(tester, settings: selectedOil);
      await _add(tester, 'Rice');
      await _add(tester, 'Oil');

      expect(find.text('GHS 10.00 each'), findsOne);
      expect(find.text('GHS 17.99 each · was GHS 19.99, 10% off'), findsOne);
      expect(find.text('GHS 27.99'), findsWidgets);
    });

    for (final (label, settings) in [
      ('no configuration', null),
      ('disabled', discountSettings(isEnabled: false)),
      (
        'expired',
        discountSettings(endsAt: now.subtract(const Duration(days: 1))),
      ),
    ]) {
      testWidgets('$label: normal prices, no discount shown', (tester) async {
        await _pump(tester, settings: settings);
        await _add(tester, 'Rice');

        expect(find.text('GHS 10.00 each'), findsOne);
        expect(find.text('Subtotal'), findsNothing);
        expect(find.textContaining('-GHS'), findsNothing);
        expect(find.text('GHS 10.00'), findsWidgets);
      });
    }

    testWidgets('settings unreadable: no promised discount, sale still works', (
      tester,
    ) async {
      final (createSale, _) = await _pump(
        tester,
        settingsError: const DiscountSettingsException(
          DiscountSettingsErrorKind.network,
        ),
      );
      await _add(tester, 'Rice');

      expect(find.text('GHS 10.00 each'), findsOne);
      expect(find.textContaining("Discounts couldn't be checked"), findsOne);

      createSale
        ..recordedTotal = 10.00
        ..recordedDiscount = 0;
      await _enterAmount(tester, 'Amount paid', '10');
      await _complete(tester);
      expect(find.text('Sale Completed'), findsOne);
      expect(find.text('Total: GHS 10.00'), findsOne);
    });
  });

  group('recorded totals', () {
    testWidgets('change comes from the recorded sale', (tester) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _enterAmount(tester, 'Amount paid', '20');
      expect(find.text('GHS 11.00'), findsWidgets); // estimated change

      await _complete(tester);

      // Only ids and quantities are sent: no price, discount or subtotal.
      expect(createSale.draftAt(0).items.map((item) => item.toJson()), [
        {'product_id': 'rice', 'quantity': 1},
      ]);
      expect(find.text('Total: GHS 9.00'), findsOne);
      expect(find.text('Discount: GHS 1.00'), findsOne);
      expect(find.text('Change: GHS 11.00'), findsOne);
      expect(find.textContaining('adjusted at checkout'), findsNothing);
    });

    testWidgets('a recorded total that differs from the estimate is shown '
        'and explained', (tester) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _enterAmount(tester, 'Amount paid', '20');
      // The discount ended before the sale was recorded.
      createSale
        ..recordedTotal = 10.00
        ..recordedDiscount = 0;

      await _complete(tester);

      expect(find.text('Total: GHS 10.00'), findsOne);
      expect(find.text('Change: GHS 10.00'), findsOne);
      expect(find.textContaining('Discount:'), findsNothing);
      expect(
        find.textContaining('adjusted at checkout (the estimate was GHS 9.00)'),
        findsOne,
      );
    });

    testWidgets('recorded, but the details could not be read: no resubmit', (
      tester,
    ) async {
      final (createSale, router) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _enterAmount(tester, 'Amount paid', '20');
      createSale.readBackFails = true;

      await _complete(tester);

      expect(find.text('Sale Recorded'), findsOne);
      expect(find.textContaining('Do not record it again'), findsOne);
      expect(find.textContaining('Change:'), findsNothing);
      expect(createSale.submissions, hasLength(1));

      await _closeDialog(tester, 'Open sale');
      expect(router.state.uri.path, '/sales/sale-1');
    });
  });

  group('payment methods', () {
    for (final (chip, method) in [
      ('Cash', 'cash'),
      ('Mobile Money', 'mobile_money'),
      ('Card', 'card'),
      ('Bank Transfer', 'bank_transfer'),
    ]) {
      testWidgets('$chip pays the discounted estimate', (tester) async {
        final (createSale, _) = await _pump(tester, settings: allTen);
        await _add(tester, 'Rice');
        await _tapVisible(tester, find.text(chip).first);
        await _enterAmount(tester, 'Amount paid', '9');

        await _complete(tester);

        final draft = createSale.submissions.single.draft;
        expect(draft.paymentMethod, method);
        expect(draft.amountPaid, 9.0);
        expect(find.text('Sale Completed'), findsOne);
      });
    }

    testWidgets('paying less than the discounted estimate is refused', (
      tester,
    ) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _enterAmount(tester, 'Amount paid', '8.99');
      await _complete(tester);

      expect(find.text('Amount paid cannot be less than the total.'), findsOne);
      expect(createSale.submissions, isEmpty);
    });
  });

  group('credit', () {
    testWidgets('no initial payment', (tester) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _chooseCustomerAndCredit(tester);
      await _complete(tester);

      final draft = createSale.submissions.single.draft;
      expect(draft.kind, SaleRequestKind.credit);
      expect(draft.amountPaid, 0.0);
      expect(draft.initialPaymentMethod, isNull);
      expect(find.text('Total: GHS 9.00'), findsOne);
    });

    testWidgets('a partial initial payment against the discounted total', (
      tester,
    ) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _chooseCustomerAndCredit(tester);
      await _enterAmount(tester, 'Initial payment', '5');
      expect(find.text('GHS 4.00'), findsWidgets); // outstanding estimate
      await _tapVisible(tester, find.text('Mobile Money').last);
      await _complete(tester);

      final draft = createSale.submissions.single.draft;
      expect(draft.amountPaid, 5.0);
      expect(draft.initialPaymentMethod, 'mobile_money');
    });

    testWidgets('an initial payment above the discounted total is refused', (
      tester,
    ) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _chooseCustomerAndCredit(tester);
      await _enterAmount(tester, 'Initial payment', '9.50');
      await _tapVisible(tester, find.text('Mobile Money').last);
      await _complete(tester);

      expect(
        find.text('Initial payment cannot exceed the sale total.'),
        findsOne,
      );
      expect(createSale.submissions, isEmpty);
    });

    testWidgets('the server refusing an initial payment above its total', (
      tester,
    ) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _chooseCustomerAndCredit(tester);
      await _enterAmount(tester, 'Initial payment', '9');
      await _tapVisible(tester, find.text('Cash').last);
      createSale.nextError = const SaleRequestException(
        SaleRequestErrorKind.rejected,
        code: 'P0001',
        serverMessage: 'Initial payment (9.00) exceeds sale total (8.50)',
      );
      await _complete(tester);

      expect(
        find.text('Initial payment cannot exceed the sale total.'),
        findsOne,
      );
      expect(find.text('Sale Completed'), findsNothing);
    });

    testWidgets('a lost connection: the same request is kept, looked up, '
        'and only retried with the same key once confirmed', (tester) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _chooseCustomerAndCredit(tester);
      await _enterAmount(tester, 'Initial payment', '5');
      await _tapVisible(tester, find.text('Cash').last);
      createSale.nextError = const SaleRequestException(
        SaleRequestErrorKind.outcomeUnknown,
      );
      await _complete(tester);

      expect(
        find.textContaining("couldn't confirm whether this sale was recorded"),
        findsOne,
      );
      expect(find.text('Sale not confirmed'), findsOne);
      expect(find.text('Sale Completed'), findsNothing);
      expect(createSale.submissions, hasLength(1), reason: 'never resent');
      expect(tester.widget<FilledButton>(_completeButton).onPressed, isNull);

      await tester.pumpAndSettle(const Duration(seconds: 5));
      await _tapVisible(tester, find.text('Check if it was recorded'));
      expect(find.text('No recorded sale found yet'), findsOne);
      expect(createSale.submissions, hasLength(1));

      await _tapVisible(tester, find.text('Retry this sale'));
      await _closeDialog(tester, 'Customer has paid: retry');

      expect(createSale.submissions, hasLength(2));
      expect(
        createSale.submissions[1].idempotencyKey,
        createSale.submissions[0].idempotencyKey,
      );
      expect(
        createSale.draftAt(1).sameRequestAs(createSale.draftAt(0)),
        isTrue,
      );
      expect(createSale.draftAt(1).initialPaymentMethod, 'cash');
      expect(find.text('Sale Completed'), findsOne);
      expect(find.textContaining('This sale is now recorded'), findsOne);
    });
  });

  group('errors', () {
    testWidgets('SMD01: a clear message, matched by code, no cost shown', (
      tester,
    ) async {
      final (createSale, _) = await _pump(tester, settings: selectedSugar);
      await _add(tester, 'Sugar');

      // On the line and in the summary.
      expect(find.textContaining('the sale may be refused'), findsNWidgets(2));
      _expectNoCost();

      await _enterAmount(tester, 'Amount paid', '7');
      createSale.nextError = const SaleRequestException(
        // The code decides; the message text is not relied on.
        SaleRequestErrorKind.discountRefused,
        code: 'SMD01',
        serverMessage: 'anything',
      );
      await _complete(tester);

      expect(find.text(_refusedMessage), findsOne);
      expect(find.text('Sale Completed'), findsNothing);
      expect(find.text('anything'), findsNothing);
      _expectNoCost();
      // The cart is kept so the product can be removed.
      expect(find.text('Your cart is empty'), findsNothing);
    });

    testWidgets('SMD01 on a credit sale gets the same message', (tester) async {
      final (createSale, _) = await _pump(tester, settings: selectedSugar);
      await _add(tester, 'Sugar');
      await _chooseCustomerAndCredit(tester);
      createSale.nextError = const SaleRequestException(
        SaleRequestErrorKind.discountRefused,
        code: 'SMD01',
        serverMessage: 'Discount cannot be applied to one or more products.',
      );
      await _complete(tester);

      expect(find.text(_refusedMessage), findsOne);
    });

    testWidgets('a lost connection on a cash sale: outcome unknown, no retry', (
      tester,
    ) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _enterAmount(tester, 'Amount paid', '9');
      createSale.nextError = const SaleRequestException(
        SaleRequestErrorKind.outcomeUnknown,
      );
      await _complete(tester);

      expect(
        find.textContaining("couldn't confirm whether this sale was recorded"),
        findsOne,
      );
      expect(find.text('Sale Completed'), findsNothing);
      expect(createSale.submissions, hasLength(1));
      expect(find.text('Your cart is empty'), findsNothing);
      expect(find.text('Sale not confirmed'), findsOne);
    });

    testWidgets('existing stock errors are still shown', (tester) async {
      final (createSale, _) = await _pump(tester, settings: allTen);
      await _add(tester, 'Rice');
      await _enterAmount(tester, 'Amount paid', '9');
      createSale.nextError = const SaleRequestException(
        SaleRequestErrorKind.rejected,
        code: 'P0001',
        serverMessage:
            'Insufficient stock for Rice. Available: 0, requested: 1',
      );
      await _complete(tester);

      expect(
        find.text('Insufficient stock for Rice. Available: 0, requested: 1'),
        findsOne,
      );
    });
  });

  testWidgets('works at phone width with a discount', (tester) async {
    await _pump(tester, settings: allTen, size: const Size(360, 1800));
    await _add(tester, 'Rice');

    expect(tester.takeException(), isNull);
    expect(find.text('-GHS 1.00'), findsOne);
    expect(find.text('GHS 9.00'), findsWidgets);
  });
}
