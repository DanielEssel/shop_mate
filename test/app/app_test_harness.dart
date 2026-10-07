/// Shared harness: the real app root and router over fake auth and shop
/// repositories.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shopmate/app/app.dart';
import 'package:shopmate/app/router/app_router.dart';
import 'package:shopmate/features/admin/presentation/providers/admin_providers.dart';
import 'package:shopmate/features/auth/domain/entities/auth_user.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:shopmate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/domain/repositories/shop_repository.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopmate/features/shop_members/presentation/providers/shop_members_providers.dart';

import '../features/admin/fake_admin_repository.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/shop_members/fake_shop_members_repository.dart';

ShopAccess shopAccessFor(
  String userId,
  ShopAccessStatus status, {
  String role = 'owner',
}) {
  return ShopAccess(
    userId: userId,
    status: status,
    shopId: status == ShopAccessStatus.active ? 'shop-$userId' : null,
    role: role,
  );
}

/// Answers shop access per user. A user with no answer yet stays loading
/// until [complete] is called.
class FakeShopRepository implements ShopRepository {
  final answers = <String, ShopAccessStatus>{};

  /// Shop role per user; anyone not listed is the owner.
  final roles = <String, String>{};
  final _pending = <String, Completer<ShopAccess>>{};
  final fetchedFor = <String>[];

  void complete(String userId, ShopAccessStatus status) {
    _pending
        .remove(userId)!
        .complete(
          shopAccessFor(userId, status, role: roles[userId] ?? 'owner'),
        );
  }

  @override
  Future<ShopAccess> fetchAccess(String userId) {
    fetchedFor.add(userId);
    final status = answers[userId];
    if (status != null) {
      return Future.value(
        shopAccessFor(userId, status, role: roles[userId] ?? 'owner'),
      );
    }
    return (_pending[userId] = Completer<ShopAccess>()).future;
  }

  @override
  Future<void> registerShop({required String name, required String phone}) {
    throw UnimplementedError();
  }
}

class NoBranding extends ShopBrandingNotifier {
  @override
  Future<ShopBrandingResult?> build() async => null;
}

const emptyDashboardSummary = DashboardSummary(
  todaySales: 0,
  todayProfit: 0,
  todayTransactions: 0,
  totalProducts: 0,
  lowStockProducts: 0,
  outOfStockProducts: 0,
  recentSales: [],
);

/// Pumps enough frames for redirects and async answers to land. The splash
/// spins forever, so `pumpAndSettle` would never return there.
Future<void> settleApp(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class AppHarness {
  AppHarness(this.container, this.auth, this.shops, this.admin);

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeShopRepository shops;
  final FakeAdminRepository admin;

  GoRouter get router => container.read(routerProvider);

  String get location => router.routerDelegate.currentConfiguration.uri.path;
}

Future<AppHarness> pumpApp(
  WidgetTester tester, {
  AuthUser? user,
  Map<String, ShopAccessStatus> answers = const {},
  Map<String, String> roles = const {},
  Set<String> platformAdminIds = const {},
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(user);
  final shops = FakeShopRepository()
    ..answers.addAll(answers)
    ..roles.addAll(roles);
  // Platform admin is decided per signed-in account, like the database.
  final admin = FakeAdminRepository(
    currentUserId: () => auth.currentUser?.id,
    adminUserIds: platformAdminIds,
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      shopRepositoryProvider.overrideWithValue(shops),
      adminRepositoryProvider.overrideWithValue(admin),
      shopMembersRepositoryProvider.overrideWithValue(
        FakeShopMembersRepository(),
      ),
      shopBrandingProvider.overrideWith(NoBranding.new),
      dashboardSummaryProvider.overrideWith(
        (ref) async => emptyDashboardSummary,
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.dispose);

  // The real app root: it watches routerProvider, which keeps the router's
  // auth and access listeners active.
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ShopInventoryApp(),
    ),
  );
  await settleApp(tester);
  return AppHarness(container, auth, shops, admin);
}
