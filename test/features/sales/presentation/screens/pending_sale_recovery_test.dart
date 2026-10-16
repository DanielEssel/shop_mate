import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/theme/app_theme.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/discounts/presentation/providers/discount_settings_providers.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/sales/domain/entities/pending_sale_request.dart';
import 'package:shopmate/features/sales/domain/entities/sale_request_exception.dart';
import 'package:shopmate/features/sales/domain/usecases/submit_sale.dart';
import 'package:shopmate/features/sales/presentation/providers/pending_sale_controller.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/sales/presentation/screens/new_sale_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../shop/shop_role_fixtures.dart';
import '../../fake_sale_repository.dart';

const _rice = Product(
  id: 'p-rice',
  name: 'Rice',
  costPrice: 10,
  sellingPrice: 15,
  stockQuantity: 5,
  lowStockThreshold: 2,
);

const _scope = PendingSaleScope(userId: 'user-1', shopId: 'shop-1');

/// A cash sale of one Rice, paid 20: what an earlier run left saved.
PendingSaleRequest _saved({PendingSaleScope scope = _scope}) =>
    PendingSaleRequest(
      idempotencyKey: 'key-saved',
      scope: scope,
      draft: const SaleDraft(
        kind: SaleRequestKind.standard,
        paymentMethod: 'cash',
        amountPaid: 20,
        items: [SaleRequestItem(productId: 'p-rice', quantity: 1)],
        estimatedTotal: 15,
      ),
      createdAt: DateTime(2026, 10, 15, 9, 30),
    );

class _Customers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => const [];
}

/// One device: its store outlives each app run ([start]).
class _Device {
  final repository = FakeSaleRepository();
  final store = InMemoryPendingSaleStore();
  var _keys = 0;
  late GoRouter router;

  /// Saved as the store writes it.
  void save(PendingSaleRequest request) =>
      store.putRaw(request.scope, jsonEncode(request.toJson()));

  List<Override> get overrides => [
    currentUserIdProvider.overrideWithValue('user-1'),
    salesProductsProvider.overrideWith((ref) async => [_rice]),
    customersProvider.overrideWith(_Customers.new),
    salesRepositoryProvider.overrideWithValue(repository),
    pendingSaleStoreProvider.overrideWithValue(store),
    shopAccessProvider.overrideWith((ref) async => activeAccess(ownerRole)),
    discountSettingsProvider.overrideWith((ref) async => null),
    salesProvider.overrideWith((ref) async => const []),
    submitSaleProvider.overrideWith(
      (ref) => SubmitSale(
        repository: repository,
        store: store,
        newKey: () => 'key-${++_keys}',
        now: () => DateTime(2026, 10, 15, 9, 30),
      ),
    ),
  ];

  /// Starts the app (again) on New Sale.
  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A new run: nothing of the previous widget tree or providers is kept.
    await tester.pumpWidget(const SizedBox());

    router = GoRouter(
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
        key: UniqueKey(),
        retry: (_, _) => null,
        overrides: overrides,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await _settle(tester);
  }
}

/// Pumps frames (a dialog's open spinner never settles).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _addRice(WidgetTester tester) =>
    _tap(tester, find.text('Rice').first);

Future<void> _pay(WidgetTester tester, String value) async {
  final field = find.widgetWithText(TextField, 'Amount paid');
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await _settle(tester);
}

Future<void> _complete(WidgetTester tester) =>
    _tap(tester, find.text('Complete Sale'));

Finder get _completeButton => find.ancestor(
  of: find.text('Complete Sale'),
  matching: find.byType(FilledButton),
);

bool _checkoutEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_completeButton).onPressed != null;

Future<void> _cashSaleWithLostAnswer(
  WidgetTester tester,
  _Device device, {
  bool recorded = false,
}) async {
  await _addRice(tester);
  await _pay(tester, '20');
  if (recorded) {
    device.repository.nextAnswerLost = true;
  } else {
    device.repository.nextError = const SaleRequestException(
      SaleRequestErrorKind.outcomeUnknown,
    );
  }
  await _complete(tester);
}

/// The controller, outside any screen, once it has loaded the saved sale.
Future<ProviderContainer> _loaded(_Device device) async {
  final container = ProviderContainer(overrides: device.overrides);
  addTearDown(container.dispose);
  container.listen(pendingSaleControllerProvider, (_, _) {});
  await container.read(shopAccessProvider.future);
  final state = await container.read(pendingSaleControllerProvider.future);
  expect(state.phase, PendingSalePhase.pending);
  return container;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('after a restart', () {
    testWidgets('a saved sale is looked up on entry and shown as already '
        'recorded, without sending it again', (tester) async {
      final device = _Device();
      final request = _saved();
      device
        ..save(request)
        ..repository.seedRecorded(request);

      await device.start(tester);

      expect(device.repository.lookups, ['key-saved']);
      expect(device.repository.submissions, isEmpty);
      expect(find.text('Sale Completed'), findsOne);
      expect(
        find.text(
          'This sale had already been recorded. Do not collect payment '
          'again.',
        ),
        findsOne,
      );
      expect(find.text('Change: GHS 5.00'), findsOne);
      expect(device.store.values, isEmpty);

      await _tap(tester, find.text('Done'));
      expect(device.router.state.uri.path, '/sales');
    });

    testWidgets('not found: new sales stay blocked; a retry needs '
        'confirmation and sends the same key', (tester) async {
      final device = _Device()..save(_saved());

      await device.start(tester);

      expect(find.text('No recorded sale found yet'), findsOne);
      expect(find.textContaining('A cash sale of 1 item'), findsOne);
      expect(_checkoutEnabled(tester), isFalse);
      expect(device.repository.submissions, isEmpty);

      // New products cannot be rung up meanwhile.
      await _addRice(tester);
      expect(find.text('Your cart is empty'), findsOne);

      // Declining the confirmation sends nothing.
      await _tap(tester, find.text('Retry this sale'));
      expect(find.text('Has the customer already paid?'), findsOne);
      await _tap(tester, find.text('Cancel'));
      expect(device.repository.submissions, isEmpty);
      expect(find.text('No recorded sale found yet'), findsOne);

      await _tap(tester, find.text('Retry this sale'));
      await _tap(tester, find.text('Customer has paid: retry'));

      expect(device.repository.submissions.single.idempotencyKey, 'key-saved');
      expect(
        device.repository.submissions.single.draft.sameRequestAs(
          _saved().draft,
        ),
        isTrue,
      );
      expect(find.text('Sale Completed'), findsOne);
      expect(
        find.text(
          'This sale is now recorded. The customer has already paid: do not '
          'collect payment again.',
        ),
        findsOne,
      );
      expect(device.store.values, isEmpty);
    });

    testWidgets('not found: setting it aside keeps it on the device and '
        'frees checkout; nothing is deleted or resent', (tester) async {
      final device = _Device()..save(_saved());
      await device.start(tester);

      expect(find.text('Cancel this sale'), findsNothing);
      await _tap(tester, find.text('Set aside'));
      expect(find.text('Set this sale aside?'), findsOne);
      expect(find.textContaining('It does not cancel the sale'), findsOne);
      await _tap(tester, find.text('Keep it'));
      expect(device.store.values, hasLength(1));
      expect(device.store.abandonedKeys(_scope), isEmpty);

      await _tap(tester, find.text('Set aside'));
      await _tap(tester, find.text('Set aside').last);

      expect(device.store.values, isEmpty);
      expect(device.store.abandonedKeys(_scope), ['key-saved']);
      expect(find.byKey(const ValueKey('pending-sale-panel')), findsNothing);
      expect(device.repository.submissions, isEmpty);

      // A new sale gets a new key; the set-aside one is never resent.
      await _addRice(tester);
      await _pay(tester, '20');
      await _complete(tester);
      expect(device.repository.submissions.single.idempotencyKey, 'key-1');
    });

    testWidgets('the cancellation race: set aside, then the original '
        'request is recorded; the cashier is told on New Sale', (tester) async {
      final request = _saved();
      final device = _Device()..save(request);
      await device.start(tester);
      await _tap(tester, find.text('Set aside'));
      await _tap(tester, find.text('Set aside').last);
      expect(find.textContaining('A sale you set aside'), findsNothing);

      // The delayed original reaches the database after all.
      device.repository.seedRecorded(request);

      device.router.go('/sales');
      await _settle(tester);
      device.router.go('/sales/new');
      await _settle(tester);

      expect(find.text('A sale you set aside was recorded'), findsOne);
      expect(find.textContaining('recorded as SL-SALE-1'), findsOne);
      expect(device.repository.submissions, isEmpty, reason: 'looked up only');
      // Checkout is not blocked by it.
      await _addRice(tester);
      expect(_checkoutEnabled(tester), isTrue);

      // Still kept until acknowledged, even across a restart.
      await device.start(tester);
      expect(find.text('A sale you set aside was recorded'), findsOne);

      await _tap(tester, find.text('Got it'));
      expect(find.text('A sale you set aside was recorded'), findsNothing);
      expect(device.store.abandonedKeys(_scope), isEmpty);
    });

    testWidgets('a failed lookup keeps it and offers no retry; it can '
        'still be set aside, not deleted', (tester) async {
      final device = _Device()..save(_saved());
      device.repository.nextLookupError = Exception('offline');

      await device.start(tester);

      expect(find.textContaining("couldn't check this sale"), findsOne);
      expect(find.text('Sale not confirmed'), findsOne);
      expect(find.text('Retry this sale'), findsNothing);
      expect(find.text('Set aside'), findsOne);
      expect(device.store.values, hasLength(1));

      // Looking up again once the connection is back.
      await _tap(tester, find.text('Check if it was recorded'));
      expect(device.repository.lookups, hasLength(2));
      expect(find.text('No recorded sale found yet'), findsOne);
    });

    testWidgets('a refused retry keeps the sale saved: the first attempt '
        'may still arrive', (tester) async {
      final device = _Device()..save(_saved());
      device.repository.nextError = const SaleRequestException(
        SaleRequestErrorKind.rejected,
        code: 'P0001',
        serverMessage: 'Insufficient stock for Rice. Available: 0',
      );
      await device.start(tester);
      // Let the lookup's message go first (messages queue).
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await _tap(tester, find.text('Retry this sale'));
      await _tap(tester, find.text('Customer has paid: retry'));

      expect(
        find.textContaining('first attempt may still be recorded'),
        findsOne,
      );
      expect(device.store.values, hasLength(1));
      expect(find.text('No recorded sale found yet'), findsOne);
      expect(_checkoutEnabled(tester), isFalse);
    });

    testWidgets('an unreadable saved sale is set aside verbatim, not '
        'deleted', (tester) async {
      const raw = '{"version": 1, truncated';
      final device = _Device();
      device.store.putRaw(_scope, raw);

      await device.start(tester);

      expect(find.text('A saved sale could not be read'), findsOne);
      expect(find.text('Check if it was recorded'), findsNothing);
      expect(device.repository.lookups, isEmpty);

      await _tap(tester, find.text('Set aside'));
      await _tap(tester, find.text('Set aside').last);

      expect(device.store.values, isEmpty);
      expect(device.store.abandoned[_scope], [raw]);
      expect(find.text('A saved sale could not be read'), findsNothing);
    });

    testWidgets('a saved sale the device cannot read at all: try again, '
        'never set aside', (tester) async {
      final device = _Device()..save(_saved());
      device.store.failLoad = true;

      await device.start(tester);

      expect(find.text('A saved sale could not be read'), findsOne);
      expect(find.text('Set aside'), findsNothing);

      device.store.failLoad = false;
      await _tap(tester, find.text('Try again'));
      expect(find.text('Sale not confirmed'), findsOne);
      expect(find.text('Check if it was recorded'), findsOne);
      expect(device.store.values, hasLength(1));
    });

    for (final (label, scope) in [
      ('another shop', const PendingSaleScope(userId: 'user-1', shopId: 's2')),
      (
        'another account',
        const PendingSaleScope(userId: 'u2', shopId: 'shop-1'),
      ),
    ]) {
      testWidgets('a sale saved for $label does not affect this one', (
        tester,
      ) async {
        final device = _Device()..save(_saved(scope: scope));
        await device.start(tester);

        expect(find.byKey(const ValueKey('pending-sale-panel')), findsNothing);
        expect(device.repository.lookups, isEmpty);
        await _addRice(tester);
        expect(_checkoutEnabled(tester), isTrue);
        expect(device.store.values.keys, [scope]);
      });
    }
  });

  group('in one session', () {
    testWidgets('an answer lost after recording: the lookup finds it, '
        'no second sale', (tester) async {
      final device = _Device();
      await device.start(tester);
      await _cashSaleWithLostAnswer(tester, device, recorded: true);

      expect(find.text('Sale not confirmed'), findsOne);
      expect(find.textContaining('do not charge the customer again'), findsOne);
      expect(_checkoutEnabled(tester), isFalse);
      expect(find.text('Retry this sale'), findsNothing);

      await tester.pumpAndSettle(const Duration(seconds: 5));
      await _tap(tester, find.text('Check if it was recorded'));

      expect(find.textContaining('had already been recorded'), findsOne);
      expect(device.repository.submissions, hasLength(1));
      expect(device.repository.recordedByKey, hasLength(1));
    });

    testWidgets('the unresolved sale survives leaving New Sale', (
      tester,
    ) async {
      final device = _Device();
      await device.start(tester);
      await _cashSaleWithLostAnswer(tester, device);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      device.router.go('/sales');
      await _settle(tester);
      device.router.go('/sales/new');
      await _settle(tester);

      // Looked up again on entry; still not recorded.
      expect(device.repository.lookups, ['key-1']);
      expect(find.text('No recorded sale found yet'), findsOne);
      expect(_checkoutEnabled(tester), isFalse);
    });

    testWidgets('duplicate taps send one request', (tester) async {
      final device = _Device();
      final gate = Completer<void>();
      device.repository.submitGate = gate;
      await device.start(tester);
      await _addRice(tester);
      await _pay(tester, '20');

      await tester.ensureVisible(_completeButton);
      await tester.pump();
      // The button shows a spinner once tapped; tap the same spot again.
      final spot = tester.getCenter(_completeButton);
      await tester.tapAt(spot);
      await tester.pump();
      await tester.tapAt(spot);
      await tester.pump();

      gate.complete();
      await _settle(tester);

      expect(device.repository.submissions, hasLength(1));
      expect(find.text('Sale Completed'), findsOne);
    });

    testWidgets('if the device cannot save the request, nothing is sent', (
      tester,
    ) async {
      final device = _Device();
      device.store.failSave = true;
      await device.start(tester);
      await _addRice(tester);
      await _pay(tester, '20');
      await _complete(tester);

      expect(device.repository.submissions, isEmpty);
      expect(find.textContaining('nothing was sent'), findsOne);
      expect(_checkoutEnabled(tester), isTrue);
    });

    testWidgets('the database not updated yet: an actionable message, '
        'nothing kept, no fallback', (tester) async {
      final device = _Device();
      device.repository.nextError = const SaleRequestException(
        SaleRequestErrorKind.serviceUnavailable,
        code: 'PGRST202',
      );
      await device.start(tester);
      await _addRice(tester);
      await _pay(tester, '20');
      await _complete(tester);

      expect(
        find.textContaining(
          "can't be recorded until ShopMate's database is "
          'updated',
        ),
        findsOne,
      );
      expect(device.repository.submissions, hasLength(1));
      expect(device.store.values, isEmpty);
      expect(find.byKey(const ValueKey('pending-sale-panel')), findsNothing);
    });

    testWidgets('a key conflict (SMI01) is explained', (tester) async {
      final device = _Device();
      device.repository.nextError = const SaleRequestException(
        SaleRequestErrorKind.keyConflict,
        code: 'SMI01',
      );
      await device.start(tester);
      await _addRice(tester);
      await _pay(tester, '20');
      await _complete(tester);

      expect(
        find.textContaining('request key was already used for a different'),
        findsOne,
      );
      expect(device.store.values, isEmpty);
    });
  });

  group('controller', () {
    test('one action at a time', () async {
      final device = _Device()..save(_saved());
      final container = await _loaded(device);

      final controller = container.read(pendingSaleControllerProvider.notifier);
      final first = controller.lookUp();
      expect(await controller.lookUp(), isNull);
      expect(
        await controller.retry(customerConfirmedPaid: true),
        isNull,
        reason: 'busy',
      );
      await first;
      expect(device.repository.lookups, hasLength(1));
      expect(device.repository.submissions, isEmpty);
    });

    test('a retry without confirmation and setting aside before any lookup '
        'are refused', () async {
      final device = _Device()..save(_saved());
      final container = await _loaded(device);
      final controller = container.read(pendingSaleControllerProvider.notifier);

      expect(await controller.retry(customerConfirmedPaid: false), isNull);
      expect(await controller.abandon(), isFalse);
      expect(device.repository.submissions, isEmpty);
      expect(device.store.values, hasLength(1));
    });
  });
}
