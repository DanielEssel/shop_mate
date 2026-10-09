import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:shopmate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:shopmate/features/inventory/presentation/screens/stock_adjustment_screen.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';

const _milo = Product(
  id: 'p1',
  name: 'Milo 400g Tin',
  costPrice: 35,
  sellingPrice: 42.5,
  stockQuantity: 40,
  lowStockThreshold: 5,
);

class _FakeAdjustStock implements AdjustStock {
  final calls = <String>[];

  @override
  Future<String> call({
    required String productId,
    required int quantity,
    required String direction,
    String? note,
  }) async {
    calls.add('$productId $direction $quantity');
    return 'm1';
  }
}

Future<_FakeAdjustStock> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final adjust = _FakeAdjustStock();

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        productsProvider.overrideWith((ref) async => [_milo]),
        adjustStockProvider.overrideWithValue(adjust),
      ],
      child: const MaterialApp(home: StockAdjustmentScreen(product: _milo)),
    ),
  );
  await tester.pumpAndSettle();
  return adjust;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the confirmation shows before and after with an arrow icon, '
      'not a glyph the font lacks', (tester) async {
    final adjust = await _pump(tester);

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.tap(find.text('Update Stock'));
    await tester.pumpAndSettle();

    expect(adjust.calls, ['p1 increase 12']);
    expect(find.text('Stock Updated'), findsOne);
    Finder inDialog(Finder finder) =>
        find.descendant(of: find.byType(AlertDialog), matching: finder);
    expect(inDialog(find.text('40')), findsOne);
    expect(inDialog(find.text('52 units')), findsOne);
    expect(inDialog(find.byIcon(Icons.arrow_forward_rounded)), findsOne);
    expect(find.textContaining('→'), findsNothing);
    expect(find.bySemanticsLabel('40 to 52 units'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing stock sends a decrease', (tester) async {
    final adjust = await _pump(tester);

    await tester.tap(find.text('Remove Stock'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.tap(find.text('Update Stock'));
    await tester.pumpAndSettle();

    expect(adjust.calls, ['p1 decrease 5']);
  });

  testWidgets('existing validation still blocks bad quantities', (
    tester,
  ) async {
    final adjust = await _pump(tester);

    await tester.tap(find.text('Update Stock'));
    await tester.pump();
    expect(
      find.text('Enter a valid quantity greater than zero.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Remove Stock'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '41');
    await tester.tap(find.text('Update Stock'));
    await tester.pump();
    expect(
      find.text('You cannot remove more stock than currently available.'),
      findsOneWidget,
    );
    expect(adjust.calls, isEmpty);
  });

  testWidgets('fits at 320px with the adjustment types in full', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 760));

    expect(tester.takeException(), isNull);
    for (final label in ['Add Stock', 'Remove Stock']) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.didExceedMaxLines, isFalse, reason: label);
      expect(find.text(label).hitTestable(), findsOne, reason: label);
    }
    expect(find.text('Update Stock').hitTestable(), findsOne);
  });
}
