import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/theme/app_theme.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/sales/domain/entities/cart_item.dart';
import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/domain/usecases/create_sale.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/sales/presentation/screens/new_sale_screen.dart';

const _rice = Product(
  id: 'p-rice',
  name: 'Rice',
  costPrice: 10,
  sellingPrice: 15,
  stockQuantity: 5,
  lowStockThreshold: 2,
);

const _soap = Product(
  id: 'p-soap',
  name: 'Soap',
  costPrice: 3,
  sellingPrice: 5,
  stockQuantity: 0,
  lowStockThreshold: 2,
);

const _ama = Customer(id: 'c-ama', name: 'Ama Mensah', phone: '0241234567');

class _FakeCreateSale implements CreateSale {
  final calls = <Map<String, Object?>>[];

  Sale _sale(double total, String method, double paid) => Sale(
    id: 'sale-1',
    saleNumber: 'SL-0001',
    totalAmount: total,
    paymentMethod: method,
    amountPaid: paid,
    changeAmount: paid > total ? paid - total : 0,
    createdAt: DateTime(2026, 10, 8, 10),
  );

  @override
  Future<Sale> call({
    String? customerId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
  }) async {
    calls.add({
      'kind': 'sale',
      'customerId': customerId,
      'items': items,
      'paymentMethod': paymentMethod,
      'amountPaid': amountPaid,
    });
    final total = items.fold<double>(
      0,
      (sum, item) => sum + 15.0 * (item['quantity'] as int),
    );
    return _sale(total, paymentMethod, amountPaid);
  }

  @override
  Future<Sale> createCreditSaleWithInitialPayment({
    required String customerId,
    required List<CartItem> items,
    required double initialPaymentAmount,
    required String? initialPaymentMethod,
    required String idempotencyKey,
  }) async {
    calls.add({
      'kind': 'credit',
      'customerId': customerId,
      'quantity': items.single.quantity,
      'initialPaymentAmount': initialPaymentAmount,
      'initialPaymentMethod': initialPaymentMethod,
      'idempotencyKey': idempotencyKey,
    });
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    return _sale(total, 'credit', initialPaymentAmount);
  }
}

class _Customers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => const [_ama];
}

Future<(_FakeCreateSale, GoRouter)> _pump(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final createSale = _FakeCreateSale();
  final router = GoRouter(
    initialLocation: '/sales/new',
    routes: [
      GoRoute(
        path: '/sales',
        builder: (_, _) => const Scaffold(body: Text('Sales list')),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const NewSaleScreen()),
          GoRoute(
            path: ':id/receipt',
            builder: (_, state) =>
                Scaffold(body: Text('Receipt ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        salesProductsProvider.overrideWith((ref) async => [_rice, _soap]),
        customersProvider.overrideWith(_Customers.new),
        createSaleProvider.overrideWithValue(createSale),
        // Keep the screen's invalidations away from real repositories.
        salesProvider.overrideWith((ref) async => const []),
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

/// Taps Complete Sale. While the success dialog is open the button keeps
/// its spinner, so this pumps frames instead of waiting to settle.
Future<void> _complete(WidgetTester tester) async {
  final button = find.text('Complete Sale');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Closes the success dialog with [label] and lets navigation finish.
Future<void> _closeDialog(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _addRice(WidgetTester tester) async {
  // Phone rows have an add button; desktop tiles are tapped directly.
  final addButton = find.byTooltip('Add Rice');
  await _tapVisible(
    tester,
    addButton.evaluate().isNotEmpty ? addButton : find.text('Rice').first,
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

Finder get _completeButton => find.ancestor(
  of: find.text('Complete Sale'),
  matching: find.byType(FilledButton),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final (label, size) in [
    ('phone', const Size(390, 1600)),
    ('desktop', const Size(1280, 1000)),
  ]) {
    group(label, () {
      testWidgets('Complete Sale is disabled until a product is added', (
        tester,
      ) async {
        await _pump(tester, size: size);

        expect(find.text('Your cart is empty'), findsOneWidget);
        expect(tester.widget<FilledButton>(_completeButton).onPressed, isNull);

        await _addRice(tester);

        expect(find.text('Your cart is empty'), findsNothing);
        expect(find.text('GHS 15.00 each'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(_completeButton).onPressed,
          isNotNull,
        );
      });

      testWidgets('out-of-stock products cannot be added', (tester) async {
        await _pump(tester, size: size);

        expect(find.byTooltip('Add Soap'), findsNothing);
        await tester.tap(find.text('Soap').first, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Your cart is empty'), findsOneWidget);
      });

      testWidgets('quantity follows stock and the line total updates', (
        tester,
      ) async {
        await _pump(tester, size: size);
        await _addRice(tester);

        final increase = find.byTooltip('Increase Rice');
        for (var i = 0; i < 6; i++) {
          await _tapVisible(tester, increase);
        }
        // Capped at the 5 in stock.
        expect(find.text('GHS 75.00'), findsWidgets);
        expect(find.textContaining('all 5 in stock'), findsOneWidget);

        await _tapVisible(tester, find.byTooltip('Remove Rice'));
        expect(find.text('Your cart is empty'), findsOneWidget);
      });

      testWidgets('a short cash payment is refused', (tester) async {
        final (createSale, _) = await _pump(tester, size: size);
        await _addRice(tester);
        await _enterAmount(tester, 'Amount paid', '10');

        await _complete(tester);

        expect(
          find.text('Amount paid cannot be less than the total.'),
          findsOneWidget,
        );
        expect(createSale.calls, isEmpty);
      });

      testWidgets('a cash sale completes and shows the change', (tester) async {
        final (createSale, router) = await _pump(tester, size: size);
        await _addRice(tester);
        await _enterAmount(tester, 'Amount paid', '20');

        expect(find.text('GHS 5.00'), findsWidgets); // change

        await _complete(tester);

        expect(createSale.calls.single, {
          'kind': 'sale',
          'customerId': null,
          'items': [
            {'product_id': 'p-rice', 'quantity': 1},
          ],
          'paymentMethod': 'cash',
          'amountPaid': 20.0,
        });
        expect(find.text('Sale Completed'), findsOneWidget);
        expect(find.text('Change: GHS 5.00'), findsOneWidget);

        await _closeDialog(tester, 'Done');
        expect(router.state.uri.path, '/sales');
      });

      testWidgets('a credit sale needs a customer', (tester) async {
        final (createSale, _) = await _pump(tester, size: size);
        await _addRice(tester);
        await _tapVisible(tester, find.text('Credit').last);

        expect(
          find.text('Select a customer above for a credit sale.'),
          findsOneWidget,
        );

        await _complete(tester);
        expect(
          find.text('Please select a customer for a credit sale.'),
          findsOneWidget,
        );
        expect(createSale.calls, isEmpty);
      });

      testWidgets('a credit sale with an initial payment needs its tender '
          'method, then completes', (tester) async {
        final (createSale, router) = await _pump(tester, size: size);
        await _addRice(tester);

        await _tapVisible(
          tester,
          find.byType(DropdownButtonFormField<String?>),
        );
        await tester.tap(find.text('Ama Mensah • 0241234567').last);
        await tester.pumpAndSettle();

        await _tapVisible(tester, find.text('Credit').last);
        await _enterAmount(tester, 'Initial payment', '5');
        expect(find.text('Initial payment method'), findsOneWidget);

        await _complete(tester);
        expect(
          find.text('Select a tender method for the initial payment.'),
          findsOneWidget,
        );
        expect(createSale.calls, isEmpty);

        // The tender chips are the second "Mobile Money" on screen.
        await _tapVisible(tester, find.text('Mobile Money').last);
        await _complete(tester);

        final call = createSale.calls.single;
        expect(call['kind'], 'credit');
        expect(call['customerId'], 'c-ama');
        expect(call['initialPaymentAmount'], 5.0);
        expect(call['initialPaymentMethod'], 'mobile_money');
        expect(call['idempotencyKey'], isNotEmpty);

        await _closeDialog(tester, 'View receipt');
        expect(router.state.uri.path, '/sales/sale-1/receipt');
      });

      testWidgets('lays out without overflow', (tester) async {
        await _pump(tester, size: size);
        await _addRice(tester);
        await _tapVisible(tester, find.text('Credit').last);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('works at 320px', (tester) async {
    final (createSale, _) = await _pump(tester, size: const Size(320, 1600));
    await _addRice(tester);
    await _enterAmount(tester, 'Amount paid', '15');
    await _complete(tester);

    expect(tester.takeException(), isNull);
    expect(createSale.calls.single['amountPaid'], 15.0);
  });
}
