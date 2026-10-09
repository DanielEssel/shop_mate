import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/ui/brand.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

import '../../../app/app_test_harness.dart';
import '../fake_auth_repository.dart';

Finder _officialLogo() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == ShopMateLogo.asset,
);

/// The brand header is fully on screen: logo and name, neither clipped.
void _expectBrandHeader(WidgetTester tester) {
  expect(_officialLogo(), findsOne);
  expect(find.text('ShopMate'), findsOne);
  expect(
    find.textContaining(RegExp('Shopmate|shopmate|Shop Mate')),
    findsNothing,
  );
  // Not the generic storefront stand-in any more.
  expect(find.byIcon(Icons.storefront_outlined), findsNothing);

  final screen = Offset.zero & tester.view.physicalSize;
  for (final finder in [_officialLogo(), find.text('ShopMate')]) {
    final rect = tester.getRect(finder);
    expect(screen.contains(rect.topLeft), isTrue);
    expect(screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue);
  }
  final logo = tester.getSize(_officialLogo());
  expect(logo.width, greaterThanOrEqualTo(40), reason: 'recognisable');
  expect(logo.width, lessThanOrEqualTo(72), reason: 'never dominates');
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the official logo asset is registered and is a 256px PNG', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load(ShopMateLogo.asset);
    final bytes = data.buffer.asUint8List();
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
    final view = ByteData.sublistView(bytes);
    expect(view.getUint32(16), 256);
    expect(view.getUint32(20), 256);
  });

  for (final (label, size) in [
    ('320px', const Size(320, 640)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('login, signup and recovery carry the brand at $label', (
      tester,
    ) async {
      final h = await pumpApp(tester);
      tester.view.physicalSize = size;
      await settleApp(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(h.location, '/login');
      _expectBrandHeader(tester);

      h.router.go('/signup');
      await settleApp(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create your account'), findsOne);
      _expectBrandHeader(tester);

      h.router.go('/forgot-password');
      await settleApp(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Reset your password'), findsOne);
      _expectBrandHeader(tester);
    });
  }

  testWidgets('the shop gate shows the official logo, not the shop logo', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      user: userA,
      answers: {'user-a': ShopAccessStatus.pending},
    );
    tester.view.physicalSize = const Size(320, 640);
    await settleApp(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(h.location, '/pending');
    _expectBrandHeader(tester);
  });

  testWidgets('the app shell uses the shop identity, not the app logo', (
    tester,
  ) async {
    await pumpApp(
      tester,
      user: userA,
      answers: {'user-a': ShopAccessStatus.active},
    );
    await settleApp(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // Inside the app, the header identifies the shop (its own logo or
    // initial); the ShopMate logo is for app-level screens only.
    expect(_officialLogo(), findsNothing);
  });
}
