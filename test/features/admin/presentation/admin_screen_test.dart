import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/admin/domain/entities/admin_exception.dart';
import 'package:shopmate/features/admin/domain/entities/admin_shop.dart';
import 'package:shopmate/features/admin/presentation/providers/admin_providers.dart';
import 'package:shopmate/features/admin/presentation/screens/admin_screen.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../fake_admin_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAdminRepository repository, {
  Size size = const Size(900, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWithValue('admin-1'),
        adminRepositoryProvider.overrideWithValue(repository),
        shopAccessProvider.overrideWith(
          (ref) async => const ShopAccess(
            userId: 'admin-1',
            status: ShopAccessStatus.pending,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

FakeAdminRepository _repository({List<AdminShop>? shops}) {
  return FakeAdminRepository(
    isAdmin: true,
    shops:
        shops ??
        [
          adminShop(
            'p1',
            'Pending Mart',
            AdminShopStatus.pending,
            ownerEmail: 'ama@gmail.com',
          ),
          adminShop('a1', 'Active Mart', AdminShopStatus.active),
          adminShop('s1', 'Paused Mart', AdminShopStatus.suspended),
        ],
  );
}

Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.widgetWithText(Tab, tab));
  await tester.pumpAndSettle();
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await tester.tap(_button(label).first);
  await tester.pumpAndSettle();
}

/// Any Material button (Filled, Outlined, Text…) showing [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Finder _dialogButton(String label) =>
    find.descendant(of: find.byType(AlertDialog), matching: _button(label));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('pending shops are listed with their details', (tester) async {
    await _pump(tester, _repository());

    expect(find.text('Admin'), findsOne);
    expect(find.text('Manage shops and platform access'), findsOne);
    expect(find.text('Pending Mart'), findsOne);
    expect(find.text('Owner: ama@gmail.com'), findsOne);
    expect(find.text('+233241234567'), findsOne);
    expect(find.textContaining('Registered'), findsOne);
    expect(_button('Approve'), findsOne);
  });

  testWidgets('approve asks first; Cancel changes nothing', (tester) async {
    final repository = _repository();
    await _pump(tester, repository);

    await _tapAction(tester, 'Approve');
    expect(find.text('Approve Pending Mart?'), findsOne);
    expect(
      find.textContaining('get full access to ShopMate right away'),
      findsOne,
    );

    await tester.tap(_dialogButton('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.actions, isEmpty);
    expect(find.text('Pending Mart'), findsOne);
  });

  testWidgets('a confirmed approval succeeds and refreshes both lists', (
    tester,
  ) async {
    final repository = _repository();
    await _pump(tester, repository);

    await _tapAction(tester, 'Approve');
    await tester.tap(_dialogButton('Approve'));
    await tester.pumpAndSettle();

    expect(repository.actions, ['approve p1']);
    expect(find.text('Pending Mart approved.'), findsOne);
    expect(find.text('No shops waiting for approval'), findsOne);

    await _openTab(tester, 'Active');
    expect(find.text('Pending Mart'), findsOne);
    expect(find.text('Active Mart'), findsOne);
  });

  testWidgets('a failed approval shows a safe message and keeps the shop', (
    tester,
  ) async {
    final repository = _repository()
      ..actionFailure = const AdminException(
        AdminErrorKind.actionFailed,
        code: 'XX000',
      );
    await _pump(tester, repository);

    await _tapAction(tester, 'Approve');
    await tester.tap(_dialogButton('Approve'));
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't update the shop. Please try again."),
      findsOne,
    );
    expect(find.textContaining('XX000'), findsNothing);
    expect(find.text('Pending Mart'), findsOne);
    expect(find.text('Pending Mart approved.'), findsNothing);
  });

  testWidgets('a shop that already changed refreshes the list', (tester) async {
    final repository = _repository()
      ..actionFailure = const AdminException(
        AdminErrorKind.statusChanged,
        code: '55000',
      );
    await _pump(tester, repository);

    await _tapAction(tester, 'Approve');
    await tester.tap(_dialogButton('Approve'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "This shop's status has already changed. The list has been refreshed.",
      ),
      findsOne,
    );
  });

  testWidgets('empty pending list says so', (tester) async {
    await _pump(
      tester,
      _repository(
        shops: [adminShop('a1', 'Active Mart', AdminShopStatus.active)],
      ),
    );

    expect(find.text('No shops waiting for approval'), findsOne);
    expect(find.text('New shops appear here after they register.'), findsOne);
  });

  testWidgets('active shops can be suspended after confirming', (tester) async {
    final repository = _repository();
    await _pump(tester, repository);
    await _openTab(tester, 'Active');

    expect(find.text('Active Mart'), findsOne);
    await _tapAction(tester, 'Suspend');
    expect(find.text('Suspend Active Mart?'), findsOne);
    expect(find.textContaining('loses access'), findsOne);

    await tester.tap(_dialogButton('Suspend'));
    await tester.pumpAndSettle();

    expect(repository.actions, ['suspend a1']);
    expect(find.text('Active Mart suspended.'), findsOne);
    expect(find.text('No active shops'), findsOne);
  });

  testWidgets('suspended shops can be reactivated after confirming', (
    tester,
  ) async {
    final repository = _repository();
    await _pump(tester, repository);
    await _openTab(tester, 'Suspended');

    expect(find.text('Paused Mart'), findsOne);
    await _tapAction(tester, 'Reactivate');
    expect(find.text('Reactivate Paused Mart?'), findsOne);

    await tester.tap(_dialogButton('Reactivate'));
    await tester.pumpAndSettle();

    expect(repository.actions, ['reactivate s1']);
    expect(find.text('Paused Mart reactivated.'), findsOne);
    expect(find.text('No suspended shops'), findsOne);
  });

  testWidgets('loading, then an error with Retry', (tester) async {
    final repository = _repository();
    final gate = repository.loadGate = Completer<void>();
    repository.loadFailure = const AdminException(AdminErrorKind.loadFailed);

    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          currentUserIdProvider.overrideWithValue('admin-1'),
          adminRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Loading pending shops'), findsOne);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Unable to load shops'), findsOne);
    expect(find.text('Shops could not be loaded. Please try again.'), findsOne);

    repository.loadFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Pending Mart'), findsOne);
  });

  testWidgets('one action at a time: buttons lock while it runs', (
    tester,
  ) async {
    final repository = _repository(
      shops: [
        adminShop('p1', 'Pending Mart', AdminShopStatus.pending),
        adminShop('p2', 'Second Mart', AdminShopStatus.pending),
      ],
    );
    await _pump(tester, repository);
    final gate = repository.actionGate = Completer<void>();

    await _tapAction(tester, 'Approve');
    await tester.tap(_dialogButton('Approve'));
    // Let the dialog finish closing (the spinner never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);

    // The busy shop's button shows a spinner (its label merges into the
    // button's semantics).
    expect(
      find.descendant(
        of: _button('Approve').first,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOne,
    );
    final buttons = tester.widgetList<ButtonStyleButton>(_button('Approve'));
    expect(buttons.every((button) => !button.enabled), isTrue);

    await tester.tap(_button('Approve').last);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.actions, ['approve p1']);
  });

  testWidgets('a non-admin sees no shop data, even if they reach the screen', (
    tester,
  ) async {
    final repository = _repository()..isAdmin = false;
    await _pump(tester, repository);

    expect(find.text('Not available'), findsOne);
    expect(find.text('Pending Mart'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
  });
}
