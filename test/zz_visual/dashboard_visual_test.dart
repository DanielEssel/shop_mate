// TEMPORARY visual-review renders.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

void main() {
  setUpAll(loadFonts);

  final sizes = {
    'phone': phone,
    'small': smallPhone,
    'tablet': tablet,
    'desktop': desktop,
    'desk1280': desktopSmall,
  };

  for (final entry in sizes.entries) {
    testWidgets('dashboard ${entry.key}', (tester) async {
      debugDisableShadows = false;
      await pumpVisualApp(tester, size: entry.value, location: '/dashboard');
      await shoot(tester, 'dashboard_${entry.key}');
      debugDisableShadows = true;
    });
  }

  testWidgets('dashboard staff phone', (tester) async {
    await pumpVisualApp(
      tester,
      size: phone,
      location: '/dashboard',
      role: 'staff',
    );
    await shoot(tester, 'dashboard_staff_phone');
  });
}
