// TEMPORARY visual-review renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/presentation/widgets/auth_page_frame.dart';

import '../app/app_test_harness.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadFonts);

  final sizes = {
    'phone': phone,
    'small': smallPhone,
    'tablet': tablet,
    'desktop': desktop,
  };

  for (final route in ['/login', '/signup', '/forgot-password']) {
    for (final entry in sizes.entries) {
      final name = route.substring(1);
      testWidgets('$name ${entry.key}', (tester) async {
        final h = await pumpApp(tester);
        tester.view.physicalSize = entry.value;
        h.router.go(route);
        await settleApp(tester);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          final element = tester.element(find.byType(AuthPageFrame));
          await precacheImage(
            const AssetImage(AuthPageFrame.backgroundAsset),
            element,
          );
        });
        await tester.pump();
        await shoot(tester, 'auth_${name}_${entry.key}');
      });
    }
  }
}
