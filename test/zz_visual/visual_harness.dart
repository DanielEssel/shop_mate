// TEMPORARY visual-review harness (not part of the deliverable).
// Renders real screens with sample data and real fonts to PNGs.
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/app.dart';
import 'package:shopmate/app/router/app_router.dart';
import 'package:shopmate/features/admin/presentation/providers/admin_providers.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:shopmate/features/dashboard/domain/entities/recent_sale.dart';
import 'package:shopmate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopmate/features/shop_members/presentation/providers/shop_members_providers.dart';

import '../app/app_test_harness.dart';
import '../features/admin/fake_admin_repository.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/shop_members/fake_shop_members_repository.dart';

const fontDir =
    r'C:\Users\MrEssel\AppData\Local\Temp\claude\c--Users-MrEssel-Desktop-shop-mate\f77d8ae8-8efe-464f-bae1-324153e463d0\scratchpad\fonts';

const outDir =
    r'C:\Users\MrEssel\AppData\Local\Temp\claude\c--Users-MrEssel-Desktop-shop-mate\c8a40e28-f5e6-4c4a-acc5-4515f6e70746\scratchpad\shots';

Future<void> loadFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> load(String family, String file) async {
    final bytes = await File('$fontDir\\$file').readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    await loader.load();
  }

  await load('Poppins_regular', 'Poppins-Regular.ttf');
  await load('Poppins_500', 'Poppins-Medium.ttf');
  await load('Poppins_600', 'Poppins-SemiBold.ttf');
  await load('Poppins_700', 'Poppins-Bold.ttf');
  await load('Poppins', 'Poppins-Regular.ttf');
  await load('MaterialIcons', 'materialicons-regular.otf');
}

final sampleSummary = DashboardSummary(
  todaySales: 4250.5,
  todayProfit: 1120.75,
  todayTransactions: 23,
  totalProducts: 148,
  lowStockProducts: 6,
  outOfStockProducts: 2,
  recentSales: [
    for (var i = 0; i < 5; i++)
      DashboardRecentSale(
        id: 'sale-$i',
        saleNumber: 'SL-2026-00${41 - i}',
        totalAmount: [245.0, 1320.5, 58.0, 412.25, 96.0][i],
        paymentMethod: ['cash', 'mobile_money', 'cash', 'credit', 'card'][i],
        createdAt: DateTime(2026, 10, 8, 14 - i, 12 + i * 7),
        itemCount: [3, 12, 1, 5, 2][i],
      ),
  ],
);

typedef Overrides = List<Override>;

Future<ProviderContainer> pumpVisualApp(
  WidgetTester tester, {
  required Size size,
  required String location,
  String role = 'owner',
  Overrides extra = const [],
  bool defaultBranding = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(userA);
  final shops = FakeShopRepository()
    ..answers['user-a'] = ShopAccessStatus.active
    ..roles['user-a'] = role;
  final admin = FakeAdminRepository(
    currentUserId: () => auth.currentUser?.id,
    adminUserIds: const {},
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
      if (defaultBranding) shopBrandingProvider.overrideWith(NoBranding.new),
      dashboardSummaryProvider.overrideWith((ref) async => sampleSummary),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ShopInventoryApp(),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  container.read(routerProvider).go(location);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return container;
}

Future<void> shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final renderView = tester.binding.renderViews.first;
    final layer = renderView.debugLayer! as OffsetLayer;
    final image = await layer.toImage(renderView.paintBounds);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final file = File('$outDir\\$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

const phone = Size(390, 844);
const smallPhone = Size(360, 760);
const tablet = Size(820, 1180);
const desktop = Size(1440, 900);
const desktopSmall = Size(1280, 720);
