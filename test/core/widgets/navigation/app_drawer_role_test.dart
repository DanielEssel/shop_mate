import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/widgets/navigation/app_drawer.dart';
import 'package:shopmate/features/admin/presentation/providers/admin_providers.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/more/presentation/screens/more_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../app/app_test_harness.dart';
import '../../../features/admin/fake_admin_repository.dart';
import '../../../features/auth/fake_auth_repository.dart';
import '../../../features/shop/shop_role_fixtures.dart';

const _ownerOnlyItems = [
  'Expenses',
  'Reports',
  'Inventory Report',
  'Analytics',
  'Settings',
  'Users & Permissions',
];

const _operationalItems = [
  'Dashboard',
  'Products',
  'Inventory',
  'Sales',
  'Customers',
  'Purchases',
  'Suppliers',
  'Notifications',
  'Help & Support',
  'Sign Out',
];

final _scaffoldKey = GlobalKey<ScaffoldState>();

Future<void> _pump(WidgetTester tester, Widget child, String role) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAuthRepository(userA);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith((ref) async => activeAccess(role)),
        authRepositoryProvider.overrideWithValue(auth),
        adminRepositoryProvider.overrideWithValue(FakeAdminRepository()),
        shopBrandingProvider.overrideWith(NoBranding.new),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDrawer(WidgetTester tester, String role) async {
  await _pump(
    tester,
    Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: const SizedBox(),
    ),
    role,
  );
  _scaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

Finder _inDrawer(String text) =>
    find.descendant(of: find.byType(AppDrawer), matching: find.text(text));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('drawer', () {
    testWidgets('owner sees owner-only destinations', (tester) async {
      await _openDrawer(tester, ownerRole);

      for (final item in [..._ownerOnlyItems, ..._operationalItems]) {
        expect(_inDrawer(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('attendant sees only operational destinations', (tester) async {
      await _openDrawer(tester, attendantRole);

      for (final item in _ownerOnlyItems) {
        expect(_inDrawer(item), findsNothing, reason: item);
      }
      for (final item in _operationalItems) {
        expect(_inDrawer(item), findsOneWidget, reason: item);
      }
    });
  });

  group('More', () {
    const ownerOnly = [
      'Expenses',
      'Business & Insights',
      'Business Performance',
      'Inventory Report',
      'Analytics',
      'Settings',
      'Users & Permissions',
    ];
    const operational = [
      'Customers',
      'Purchases',
      'Suppliers',
      'Notifications',
      'Help & Support',
    ];

    testWidgets('owner sees every option', (tester) async {
      await _pump(tester, const MoreScreen(), ownerRole);

      for (final item in [...ownerOnly, ...operational]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('attendant sees only operational options', (tester) async {
      await _pump(tester, const MoreScreen(), attendantRole);

      for (final item in ownerOnly) {
        expect(find.text(item), findsNothing, reason: item);
      }
      for (final item in operational) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });
  });
}
