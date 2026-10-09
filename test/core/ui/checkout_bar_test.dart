import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/ui/ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('at 320px the change due is shown whole, never cut off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CheckoutBar(
            label: 'Total · 4 items',
            amount: 'GHS 237.00',
            caption: 'Change GHS 13.00',
            action: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Complete Sale'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final caption = tester.renderObject<RenderParagraph>(
      find.text('Change GHS 13.00'),
    );
    // Scaled to fit if needed, but never ellipsised or clipped.
    expect(caption.didExceedMaxLines, isFalse);
    expect(find.text('Change GHS 13.00').hitTestable(), findsOne);
    expect(find.text('Complete Sale').hitTestable(), findsOne);
  });
}
