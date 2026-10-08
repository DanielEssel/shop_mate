import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

import '../../../app/app_test_harness.dart';
import '../fake_auth_repository.dart';

Finder _backdrop() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == AuthPageFrame.backgroundAsset,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the backdrop asset is registered and loads', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load(AuthPageFrame.backgroundAsset);
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets(
    'the photo sits in the brand panel, without semantics, beside or above '
    'the form',
    (tester) async {
      for (final (size, split) in [
        (const Size(390, 844), false), // phone
        (const Size(820, 1180), false), // portrait tablet
        (const Size(1366, 1024), true), // landscape tablet
        (const Size(1920, 1080), true), // desktop window
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          const MaterialApp(home: AuthPageFrame(child: Text('Form'))),
        );
        await tester.pumpAndSettle();

        final image = tester.widget<Image>(_backdrop());
        expect(image.fit, BoxFit.cover);
        expect(
          find.ancestor(
            of: _backdrop(),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );

        final panel = tester.getRect(_backdrop());
        final form = tester.getRect(find.text('Form'));
        if (split) {
          // Panel on the left, full height; form to its right.
          expect(panel.height, size.height);
          expect(form.left, greaterThanOrEqualTo(panel.right));
        } else {
          // Compact band across the top; form below it.
          expect(panel.width, size.width);
          expect(panel.height, lessThan(size.height / 3));
          expect(form.top, greaterThan(panel.top));
        }
        expect(form.width, lessThanOrEqualTo(AuthPageFrame.maxFormWidth));
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.reset);
    },
  );

  testWidgets('login, signup and recovery share the backdrop', (tester) async {
    final h = await pumpApp(tester);
    expect(h.location, '/login');
    expect(_backdrop(), findsOne);

    await tester.tap(find.text("Don't have an account? Sign up"));
    await settleApp(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.location, '/signup');
    expect(_backdrop(), findsOne);

    h.router.go('/forgot-password');
    await settleApp(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reset your password'), findsOne);
    expect(_backdrop(), findsOne);
  });

  testWidgets('shop gate and app screens do not use it', (tester) async {
    final pending = await pumpApp(
      tester,
      user: userA,
      answers: {'user-a': ShopAccessStatus.pending},
    );
    expect(pending.location, '/pending');
    expect(_backdrop(), findsNothing);
  });

  testWidgets('the app shell does not use it', (tester) async {
    final active = await pumpApp(
      tester,
      user: userA,
      answers: {'user-a': ShopAccessStatus.active},
    );
    expect(active.location, '/dashboard');
    expect(_backdrop(), findsNothing);
  });
}
